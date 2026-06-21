SET search_path TO quanly_phongkham, public;

-- ============================================================
-- XÓA CÁC PROCEDURE CŨ (NẾU CÓ)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_dat_lich(VARCHAR, DATE, VARCHAR, INT);
DROP PROCEDURE IF EXISTS sp_huy_lich(INT);
DROP PROCEDURE IF EXISTS sp_ket_thuc_chu_ky(INT);
DROP PROCEDURE IF EXISTS sp_nhap_thuoc(VARCHAR, INT);
DROP PROCEDURE IF EXISTS sp_kiem_tra_don_thuoc(INT);
DROP PROCEDURE IF EXISTS sp_tao_lich_tai_kham(INT);
DROP PROCEDURE IF EXISTS sp_tao_nhac_nho(VARCHAR, INT, INT);
DROP PROCEDURE IF EXISTS sp_gui_nhac_nho();
DROP PROCEDURE IF EXISTS sp_thanh_toan_tien_kham(INT, VARCHAR);
DROP PROCEDURE IF EXISTS sp_thanh_toan_thuoc(INT, VARCHAR);
DROP PROCEDURE IF EXISTS sp_thong_ke_doanh_thu(DATE, DATE);

-- ============================================================
-- 1. ĐẶT LỊCH
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_dat_lich(
    p_maBN VARCHAR(20),
    p_ngay DATE,
    p_maBS VARCHAR(20) DEFAULT NULL,
    p_caSo INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBS VARCHAR(20);
    v_ngay DATE := p_ngay;
    v_ca INT := COALESCE(p_caSo, 1);
    v_batdau TIMESTAMP;
    v_ketthuc TIMESTAMP;
BEGIN
    -- Kiểm tra bệnh nhân tồn tại
    IF NOT EXISTS (SELECT 1 FROM "BenhNhan" WHERE "MaBN" = p_maBN) THEN
        RAISE EXCEPTION 'Bệnh nhân % không tồn tại.', p_maBN;
    END IF;

    -- 🚫 KHÔNG CHO PHÉP ĐẶT LỊCH TRONG QUÁ KHỨ (ngày nhỏ hơn hôm nay)
    IF p_ngay < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt lịch trong quá khứ. Ngày đã chọn: %', p_ngay;
    END IF;

    -- Chỉ chặn nếu bệnh nhân có lịch đang hoạt động (Chờ khám hoặc Đang khám)
    IF EXISTS (
        SELECT 1
        FROM "LichHen"
        WHERE "MaBN" = p_maBN
          AND "TrangThai" IN ('Chờ khám', 'Đang khám')
    ) THEN
        RAISE EXCEPTION 'Bệnh nhân % đã có lịch hẹn chưa hoàn thành (Chờ khám hoặc Đang khám).', p_maBN;
    END IF;

    LOOP
        IF p_maBS IS NOT NULL THEN
            SELECT bs."MaBS"
            INTO v_maBS
            FROM "BacSi" bs
            WHERE bs."MaBS" = p_maBS
              AND EXISTS (
                  SELECT 1 FROM "CaLamViec" c
                  WHERE c."MaBS" = bs."MaBS" AND c."NgayLam" = v_ngay
              )
              AND NOT EXISTS (
                  SELECT 1 FROM "LichHen" lh
                  WHERE lh."MaBS" = bs."MaBS"
                    AND DATE(lh."ThoiGianBatDau") = v_ngay
                    AND lh."CaSo" = v_ca
                    AND lh."TrangThai" IN ('Chờ khám', 'Đang khám')
              );
        ELSE
            v_maBS := NULL;
        END IF;

        IF v_maBS IS NULL THEN
            SELECT bs."MaBS"
            INTO v_maBS
            FROM "BacSi" bs
            WHERE EXISTS (
                  SELECT 1 FROM "CaLamViec" c
                  WHERE c."MaBS" = bs."MaBS" AND c."NgayLam" = v_ngay
              )
              AND NOT EXISTS (
                  SELECT 1 FROM "LichHen" lh
                  WHERE lh."MaBS" = bs."MaBS"
                    AND DATE(lh."ThoiGianBatDau") = v_ngay
                    AND lh."CaSo" = v_ca
                    AND lh."TrangThai" IN ('Chờ khám', 'Đang khám')
              )
            ORDER BY bs."MaBS"
            LIMIT 1;
        END IF;

        IF v_maBS IS NOT NULL THEN
            EXIT;
        END IF;

        v_ca := v_ca + 1;
        IF v_ca > 6 THEN
            v_ca := 1;
            v_ngay := v_ngay + 1;
        END IF;
    END LOOP;

    -- Tính thời gian bắt đầu và kết thúc của ca
    v_batdau := v_ngay + CASE v_ca
        WHEN 1 THEN TIME '08:00'
        WHEN 2 THEN TIME '09:30'
        WHEN 3 THEN TIME '11:00'
        WHEN 4 THEN TIME '13:00'
        WHEN 5 THEN TIME '14:30'
        WHEN 6 THEN TIME '16:00'
    END;

    v_ketthuc := v_ngay + CASE v_ca
        WHEN 1 THEN TIME '09:30'
        WHEN 2 THEN TIME '11:00'
        WHEN 3 THEN TIME '12:30'
        WHEN 4 THEN TIME '14:30'
        WHEN 5 THEN TIME '16:00'
        WHEN 6 THEN TIME '17:30'
    END;

    -- 🚫 KIỂM TRA CA ĐÃ QUA TRONG NGÀY HÔM NAY
    IF p_ngay = CURRENT_DATE AND v_batdau < NOW() THEN
        RAISE EXCEPTION 'Ca khám đã qua trong ngày hôm nay (ca %: % - %). Vui lòng chọn ca khác hoặc ngày khác.',
            v_ca, v_batdau::TIME, v_ketthuc::TIME;
    END IF;

    INSERT INTO "LichHen" (
        "MaBN", "MaBS", "CaSo", "ThoiGianBatDau", "ThoiGianKetThuc", "TrangThai"
    ) VALUES (
        p_maBN, v_maBS, v_ca, v_batdau, v_ketthuc, 'Chờ khám'
    );

    RAISE NOTICE 'Đặt lịch thành công. BN %, BS %, ngày %, ca %', p_maBN, v_maBS, v_ngay, v_ca;
END;
$$;

-- ============================================================
-- 2. HỦY LỊCH
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_huy_lich(p_maLH INT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM "LichHen"
        WHERE "MaLH" = p_maLH AND "TrangThai" IN ('Chờ khám','Đang khám')
    ) THEN
        RAISE EXCEPTION 'Không thể hủy lịch hẹn này.';
    END IF;
    UPDATE "LichHen" SET "TrangThai" = 'Đã hủy' WHERE "MaLH" = p_maLH;
END;
$$;

-- ============================================================
-- 3. KẾT THÚC CHU KỲ TÁI KHÁM
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_ket_thuc_chu_ky(p_maChuKy INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "ChuKyTaiKham"
    SET "TrangThai" = 'Kết thúc', "KetThuc" = CURRENT_DATE
    WHERE "MaChuKy" = p_maChuKy;
END;
$$;

-- ============================================================
-- 4. NHẬP THUỐC
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_nhap_thuoc(p_maThuoc VARCHAR(30), p_soLuong INT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_soLuong <= 0 THEN
        RAISE EXCEPTION 'Số lượng nhập phải lớn hơn 0.';
    END IF;
    UPDATE "Thuoc" SET "SoLuongTon" = "SoLuongTon" + p_soLuong
    WHERE "MaThuoc" = p_maThuoc;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Thuốc % không tồn tại.', p_maThuoc;
    END IF;
END;
$$;

-- ============================================================
-- 5. KIỂM TRA TỒN KHO ĐƠN THUỐC
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_kiem_tra_don_thuoc(p_maBA INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_thieu BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM "DonThuoc" dt
        JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
        WHERE dt."MaBA" = p_maBA
          AND dt."SoLuong" > t."SoLuongTon"
    ) INTO v_thieu;

    IF v_thieu THEN
        RAISE EXCEPTION 'Không đủ tồn kho để xuất thuốc cho bệnh án %', p_maBA;
    END IF;

    UPDATE "DonThuoc"
    SET "TrangThai" = 'Chờ phát thuốc'
    WHERE "MaBA" = p_maBA
      AND "TrangThai" = 'Chờ xử lý';
END;
$$;

-- ============================================================
-- 6. TẠO LỊCH TÁI KHÁM TỪ CHU KỲ
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_tao_lich_tai_kham(p_maChuKy INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBN VARCHAR(20);
    v_maBS VARCHAR(20);
    v_ngay DATE;
    v_chuky INT;
    v_ngay_tai_kham DATE;
BEGIN
    SELECT "MaBN", "MaBS", "BatDau", "ChuKyNgay"
    INTO v_maBN, v_maBS, v_ngay, v_chuky
    FROM "ChuKyTaiKham"
    WHERE "MaChuKy" = p_maChuKy AND "TrangThai" = 'Đang hoạt động';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Chu kỳ % không tồn tại hoặc không hoạt động.', p_maChuKy;
    END IF;

    v_ngay_tai_kham := v_ngay + v_chuky;
    CALL sp_dat_lich(v_maBN, v_ngay_tai_kham, v_maBS, NULL);
    UPDATE "ChuKyTaiKham" SET "BatDau" = v_ngay_tai_kham
    WHERE "MaChuKy" = p_maChuKy;
END;
$$;

-- ============================================================
-- 7. TẠO THIẾT LẬP NHẮC NHỞ
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_tao_nhac_nho(
    p_maBN VARCHAR(20),
    p_maLH INT DEFAULT NULL,
    p_maChuKy INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "ThietLapNhacNho" (
        "MaBN", "MaLH", "MaChuKy", "SoNgayTruoc", "Kenh", "TrangThai"
    ) VALUES (
        p_maBN, p_maLH, p_maChuKy, 1, 'sms', 'Đang hoạt động'
    );
END;
$$;

-- ============================================================
-- 8. GỬI NHẮC NHỞ
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_gui_nhac_nho()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_maNN INT;
    v_noidung TEXT;
    v_caSo INT;
    v_thoigian TEXT;
BEGIN
    FOR r IN (
        SELECT tl."MaThietLap", tl."MaBN", lh."ThoiGianBatDau"::DATE AS ngay_hen,
               lh."CaSo", 'Lịch hẹn' AS loai
        FROM "ThietLapNhacNho" tl
        JOIN "LichHen" lh ON lh."MaLH" = tl."MaLH"
        WHERE tl."TrangThai" = 'Đang hoạt động'
          AND lh."ThoiGianBatDau"::DATE = CURRENT_DATE + tl."SoNgayTruoc"
        UNION ALL
        SELECT tl."MaThietLap", tl."MaBN", ck."BatDau" + ck."ChuKyNgay" AS ngay_hen,
               NULL AS "CaSo", 'Tái khám' AS loai
        FROM "ThietLapNhacNho" tl
        JOIN "ChuKyTaiKham" ck ON ck."MaChuKy" = tl."MaChuKy"
        WHERE tl."TrangThai" = 'Đang hoạt động'
          AND ck."BatDau" + ck."ChuKyNgay" = CURRENT_DATE + tl."SoNgayTruoc"
    ) LOOP
        IF r.loai = 'Lịch hẹn' THEN
            v_caSo := r."CaSo";
            v_thoigian := CASE v_caSo
                WHEN 1 THEN '08:00-09:30' WHEN 2 THEN '09:30-11:00'
                WHEN 3 THEN '11:00-12:30' WHEN 4 THEN '13:00-14:30'
                WHEN 5 THEN '14:30-16:00' WHEN 6 THEN '16:00-17:30'
                ELSE ''
            END;
            v_noidung := format('Bạn có lịch khám vào ngày %s (ca %s: %s). Vui lòng đến đúng giờ.',
                to_char(r.ngay_hen, 'DD/MM/YYYY'), v_caSo, v_thoigian);
        ELSE
            v_noidung := format('Đã đến thời gian tái khám vào ngày %s. Vui lòng đặt lịch hẹn.',
                to_char(r.ngay_hen, 'DD/MM/YYYY'));
        END IF;

        INSERT INTO "NhacNho" ("MaBN", "MaChuKy", "SoLuong")
        VALUES (r."MaBN", COALESCE(
            (SELECT "MaChuKy" FROM "ThietLapNhacNho" WHERE "MaThietLap" = r."MaThietLap"), 1
        ), 1) RETURNING "MaNN" INTO v_maNN;

        INSERT INTO "LoiNhac" ("MaNN", "ThoiGianGui", "TrangThai")
        VALUES (v_maNN, NOW(), 'Đã gửi');

        INSERT INTO "LichSuNhacNho" ("MaThietLap", "NoiDung", "TrangThai")
        VALUES (r."MaThietLap", v_noidung, 'Đã gửi');
    END LOOP;
END;
$$;

-- ============================================================
-- 9. THANH TOÁN TIỀN KHÁM
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_thanh_toan_tien_kham(
    p_maHD INT,
    p_phuongthuc VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBA INT;
    v_tienkham DECIMAL(12,2);
BEGIN
    SELECT "MaBA", "TienKham" INTO v_maBA, v_tienkham
    FROM "HoaDon" WHERE "MaHD" = p_maHD;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tồn tại hóa đơn %', p_maHD;
    END IF;
    IF v_tienkham = 0 THEN
        RAISE EXCEPTION 'Hóa đơn này không có tiền khám để thanh toán.';
    END IF;

    UPDATE "HoaDon"
    SET "PhuongThuc" = p_phuongthuc,
        "TrangThai" = CASE WHEN "TienThuoc" = 0 THEN 'Đã thanh toán' ELSE 'Đã thanh toán tiền khám' END,
        "NgayThanhToan" = CURRENT_TIMESTAMP
    WHERE "MaHD" = p_maHD;

    IF NOT EXISTS (
        SELECT 1 FROM "ChiTietDoanhThu"
        WHERE "MaHD" = p_maHD AND "LoaiDoanhThu" = 'Tiền khám'
    ) THEN
        INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu", "LoaiDoanhThu")
        VALUES (p_maHD, v_tienkham, 'Tiền khám');
    END IF;
END;
$$;

-- ============================================================
-- 10. THANH TOÁN TIỀN THUỐC
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_thanh_toan_thuoc(
    p_maHD INT,
    p_phuongthuc VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBA INT;
    v_tienthuoc DECIMAL(12,2);
BEGIN
    SELECT "MaBA" INTO v_maBA FROM "HoaDon" WHERE "MaHD" = p_maHD;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tồn tại hóa đơn %', p_maHD;
    END IF;

    CALL sp_kiem_tra_don_thuoc(v_maBA);

    SELECT COALESCE(SUM(dt."SoLuong" * t."DonGia"), 0)
    INTO v_tienthuoc
    FROM "DonThuoc" dt
    JOIN "Thuoc" t ON t."MaThuoc" = dt."MaThuoc"
    WHERE dt."MaBA" = v_maBA
      AND dt."TrangThai" = 'Chờ xử lý';

    UPDATE "HoaDon"
    SET "TienThuoc" = v_tienthuoc,
        "TongTien" = "TienKham" + v_tienthuoc,
        "PhuongThuc" = p_phuongthuc,
        "TrangThai" = 'Đã thanh toán',
        "NgayThanhToan" = CURRENT_TIMESTAMP
    WHERE "MaHD" = p_maHD;

    INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu", "LoaiDoanhThu")
    VALUES (p_maHD, v_tienthuoc, 'Tiền thuốc');
END;
$$;

-- ============================================================
-- 11. THỐNG KÊ DOANH THU (IN RA NOTICE)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_thong_ke_doanh_thu(
    p_tu_ngay DATE,
    p_den_ngay DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tong_dt NUMERIC(12,2);
    v_dt_kham NUMERIC(12,2);
    v_dt_thuoc NUMERIC(12,2);
    v_so_hd INT;
BEGIN
    SELECT COALESCE(SUM("DoanhThu"),0) INTO v_tong_dt
    FROM "ChiTietDoanhThu" WHERE "NgayGhiNhan" BETWEEN p_tu_ngay AND p_den_ngay;

    SELECT COALESCE(SUM("DoanhThu"),0) INTO v_dt_kham
    FROM "ChiTietDoanhThu"
    WHERE "LoaiDoanhThu" = 'Tiền khám'
      AND "NgayGhiNhan" BETWEEN p_tu_ngay AND p_den_ngay;

    SELECT COALESCE(SUM("DoanhThu"),0) INTO v_dt_thuoc
    FROM "ChiTietDoanhThu"
    WHERE "LoaiDoanhThu" = 'Tiền thuốc'
      AND "NgayGhiNhan" BETWEEN p_tu_ngay AND p_den_ngay;

    SELECT COUNT(DISTINCT "MaHD") INTO v_so_hd
    FROM "ChiTietDoanhThu"
    WHERE "NgayGhiNhan" BETWEEN p_tu_ngay AND p_den_ngay;

    RAISE NOTICE '=========================================';
    RAISE NOTICE 'TỪ % ĐẾN %', p_tu_ngay, p_den_ngay;
    RAISE NOTICE 'Tổng doanh thu : %', v_tong_dt;
    RAISE NOTICE 'Tiền khám      : %', v_dt_kham;
    RAISE NOTICE 'Tiền thuốc     : %', v_dt_thuoc;
    RAISE NOTICE 'Số hóa đơn     : %', v_so_hd;
    RAISE NOTICE '=========================================';
END;
$$;