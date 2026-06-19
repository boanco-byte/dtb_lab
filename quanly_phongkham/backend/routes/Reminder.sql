SET search_path TO quanly_phongkham, public;

-- Bảng cấu hình nhắc nhở
CREATE TABLE IF NOT EXISTS "ThietLapNhacNho" (
    "MaThietLap" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaChuKy" INT REFERENCES "ChuKyTaiKham"("MaChuKy") ON DELETE CASCADE,
    "MaLH" INT REFERENCES "LichHen"("MaLH") ON DELETE CASCADE,
    "SoNgayTruoc" INT NOT NULL DEFAULT 1,
    "Kenh" VARCHAR(20) NOT NULL DEFAULT 'sms',
    "TrangThai" VARCHAR(50) DEFAULT 'Đang hoạt động',
    CONSTRAINT "chk_kenh" CHECK ("Kenh" IN ('sms', 'email', 'app_push')),
    CONSTRAINT "chk_trangthai_thietlap" CHECK ("TrangThai" IN ('Đang hoạt động', 'Tạm dừng', 'Đã hủy')),
    CONSTRAINT "chk_co_ma_lich_hoac_chuky" CHECK (
        ("MaLH" IS NOT NULL AND "MaChuKy" IS NULL) OR
        ("MaChuKy" IS NOT NULL AND "MaLH" IS NULL)
    )
);

-- Bảng mẫu lời nhắc
CREATE TABLE IF NOT EXISTS "MauLoiNhac" (
    "MaMau" SERIAL PRIMARY KEY,
    "TenMau" VARCHAR(100) NOT NULL,
    "NoiDung" TEXT NOT NULL,
    "Loai" VARCHAR(50) NOT NULL,
    "Kenh" VARCHAR(20) DEFAULT 'sms'
);

-- Bảng lịch sử gửi nhắc nhở
CREATE TABLE IF NOT EXISTS "LichSuNhacNho" (
    "MaLS" SERIAL PRIMARY KEY,
    "MaThietLap" INT NOT NULL REFERENCES "ThietLapNhacNho"("MaThietLap") ON DELETE CASCADE,
    "ThoiGianGui" TIMESTAMP NOT NULL DEFAULT NOW(),
    "NoiDung" TEXT NOT NULL,
    "TrangThai" VARCHAR(50) DEFAULT 'Đã gửi',
    "GhiChu" TEXT,
    CONSTRAINT "chk_trangthai_log" CHECK ("TrangThai" IN ('Đã gửi', 'Lỗi', 'Chưa gửi'))
);

-- Index
CREATE INDEX idx_thietlap_mabn ON "ThietLapNhacNho" ("MaBN");
CREATE INDEX idx_thietlap_malh ON "ThietLapNhacNho" ("MaLH");
CREATE INDEX idx_thietlap_machuky ON "ThietLapNhacNho" ("MaChuKy");
CREATE INDEX idx_lichsu_mathietlap ON "LichSuNhacNho" ("MaThietLap");
CREATE INDEX idx_lichsu_thoigian ON "LichSuNhacNho" ("ThoiGianGui");

-- Trigger: Khi thêm lịch hẹn mới, tự động tạo thiết lập nhắc nhở
CREATE OR REPLACE FUNCTION trg_lichhen_tao_nhacnho()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "ThietLapNhacNho" ("MaBN", "MaLH", "SoNgayTruoc", "Kenh", "TrangThai")
    VALUES (NEW."MaBN", NEW."MaLH", 1, 'sms', 'Đang hoạt động')
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_lichhen_tao_nhacnho
AFTER INSERT ON "LichHen"
FOR EACH ROW
EXECUTE FUNCTION trg_lichhen_tao_nhacnho();

-- Trigger: Khi thêm chu kỳ tái khám, tự động tạo thiết lập nhắc nhở
CREATE OR REPLACE FUNCTION trg_chuky_tao_nhacnho()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "ThietLapNhacNho" ("MaBN", "MaChuKy", "SoNgayTruoc", "Kenh", "TrangThai")
    VALUES (NEW."MaBN", NEW."MaChuKy", 2, 'sms', 'Đang hoạt động')
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_chuky_tao_nhacnho
AFTER INSERT ON "ChuKyTaiKham"
FOR EACH ROW
EXECUTE FUNCTION trg_chuky_tao_nhacnho();

-- Procedure gửi nhắc nhở tự động (gọi hàng ngày)
CREATE OR REPLACE PROCEDURE sp_gui_nhac_nho_tu_dong()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    v_noi_dung TEXT;
BEGIN
    FOR rec IN
        SELECT 
            tn."MaThietLap",
            tn."MaBN",
            tn."MaLH",
            tn."MaChuKy",
            tn."Kenh",
            tn."SoNgayTruoc",
            lh."ThoiGianBatDau",
            bn."HoTen" AS ten_benh_nhan
        FROM "ThietLapNhacNho" tn
        LEFT JOIN "LichHen" lh ON tn."MaLH" = lh."MaLH"
        JOIN "BenhNhan" bn ON tn."MaBN" = bn."MaBN"
        WHERE tn."TrangThai" = 'Đang hoạt động'
          AND DATE(lh."ThoiGianBatDau") = CURRENT_DATE + (tn."SoNgayTruoc" || ' day')::INTERVAL
          AND NOT EXISTS (
              SELECT 1 FROM "LichSuNhacNho" ls
              WHERE ls."MaThietLap" = tn."MaThietLap"
                AND DATE(ls."ThoiGianGui") = CURRENT_DATE
          )
    LOOP
        v_noi_dung := format('Xin chào %s, bạn có lịch hẹn khám vào ngày %s. Vui lòng đến đúng giờ.', 
                              rec.ten_benh_nhan, 
                              to_char(rec."ThoiGianBatDau", 'DD/MM/YYYY HH24:MI'));
        INSERT INTO "LichSuNhacNho" ("MaThietLap", "ThoiGianGui", "NoiDung", "TrangThai")
        VALUES (rec."MaThietLap", NOW(), v_noi_dung, 'Đã gửi');
    END LOOP;
END;
$$;

-- View tổng hợp nhắc nhở cho bệnh nhân
CREATE OR REPLACE VIEW "vw_NhacNhoBenhNhan" AS
SELECT 
    bn."MaBN",
    bn."HoTen",
    tn."MaThietLap",
    tn."SoNgayTruoc",
    tn."Kenh",
    tn."TrangThai" AS trang_thai_thiet_lap,
    lh."ThoiGianBatDau" AS thoi_gian_lich_hen,
    ls."ThoiGianGui" AS thoi_gian_gui,
    ls."NoiDung",
    ls."TrangThai" AS trang_thai_gui
FROM "BenhNhan" bn
LEFT JOIN "ThietLapNhacNho" tn ON bn."MaBN" = tn."MaBN"
LEFT JOIN "LichHen" lh ON tn."MaLH" = lh."MaLH"
LEFT JOIN "LichSuNhacNho" ls ON tn."MaThietLap" = ls."MaThietLap"
ORDER BY bn."MaBN", ls."ThoiGianGui" DESC;