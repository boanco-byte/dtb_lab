SET search_path TO quanly_phongkham, public;

-- ============================================================
-- 1. CẬP NHẬT HÓA ĐƠN KHI ĐƠN THUỐC THAY ĐỔI
-- ============================================================
DROP TRIGGER IF EXISTS trg_donthuoc_cap_nhat_hoadon ON "DonThuoc";
DROP FUNCTION IF EXISTS trg_fn_cap_nhat_hoa_don();

CREATE OR REPLACE FUNCTION trg_fn_cap_nhat_hoa_don()
RETURNS TRIGGER AS $$
DECLARE
    v_maBA INT;
    v_tien_thuoc DECIMAL(12,2);
BEGIN
    v_maBA := COALESCE(NEW."MaBA", OLD."MaBA");
    SELECT COALESCE(SUM(dt."SoLuong" * t."DonGia"), 0)
    INTO v_tien_thuoc
    FROM "DonThuoc" dt
    JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
    WHERE dt."MaBA" = v_maBA;
    UPDATE "HoaDon"
    SET "TienThuoc" = v_tien_thuoc,
        "TongTien" = "TienKham" + v_tien_thuoc
    WHERE "MaBA" = v_maBA;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_donthuoc_cap_nhat_hoadon
AFTER INSERT OR UPDATE OR DELETE ON "DonThuoc"
FOR EACH ROW
EXECUTE FUNCTION trg_fn_cap_nhat_hoa_don();

-- ============================================================
-- 2. TẠO HÓA ĐƠN KHI TẠO BỆNH ÁN
-- ============================================================
DROP TRIGGER IF EXISTS trg_tao_hoa_don ON "BenhAn";
DROP FUNCTION IF EXISTS fn_tao_hoa_don();

CREATE OR REPLACE FUNCTION fn_tao_hoa_don()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "HoaDon" ("MaBA") VALUES (NEW."MaBA");
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tao_hoa_don
AFTER INSERT ON "BenhAn"
FOR EACH ROW
EXECUTE FUNCTION fn_tao_hoa_don();

-- ============================================================
-- 3. TỰ ĐỘNG TẠO TÀI KHOẢN BỆNH NHÂN
-- ============================================================
DROP TRIGGER IF EXISTS trg_tao_tai_khoan_benh_nhan ON "BenhNhan";
DROP FUNCTION IF EXISTS fn_tao_tai_khoan_benh_nhan();

CREATE OR REPLACE FUNCTION fn_tao_tai_khoan_benh_nhan()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO "TaiKhoanBenhNhan" ("MaBN", "MatKhauHash")
    VALUES (NEW."MaBN", crypt(COALESCE(NEW."SDT", '123456'), gen_salt('bf')))
    ON CONFLICT ("MaBN") DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tao_tai_khoan_benh_nhan
AFTER INSERT ON "BenhNhan"
FOR EACH ROW
EXECUTE FUNCTION fn_tao_tai_khoan_benh_nhan();

-- ============================================================
-- 4. NHẮC NHỞ LỊCH HẸN
-- ============================================================
DROP TRIGGER IF EXISTS trg_lichhen_tao_nhacnho ON "LichHen";
DROP FUNCTION IF EXISTS fn_nhac_nho_lich_hen();

CREATE OR REPLACE FUNCTION fn_nhac_nho_lich_hen()
RETURNS TRIGGER AS $$
BEGIN
    CALL sp_tao_nhac_nho(NEW."MaBN", NEW."MaLH", NULL);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lichhen_tao_nhacnho
AFTER INSERT ON "LichHen"
FOR EACH ROW
EXECUTE FUNCTION fn_nhac_nho_lich_hen();

-- ============================================================
-- 5. NHẮC NHỞ TÁI KHÁM
-- ============================================================
DROP TRIGGER IF EXISTS trg_chuky_tao_nhacnho ON "ChuKyTaiKham";
DROP FUNCTION IF EXISTS fn_nhac_nho_tai_kham();

CREATE OR REPLACE FUNCTION fn_nhac_nho_tai_kham()
RETURNS TRIGGER AS $$
BEGIN
    CALL sp_tao_nhac_nho(NEW."MaBN", NULL, NEW."MaChuKy");
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chuky_tao_nhacnho
AFTER INSERT ON "ChuKyTaiKham"
FOR EACH ROW
EXECUTE FUNCTION fn_nhac_nho_tai_kham();

-- ============================================================
-- 6. TẠO LỊCH TÁI KHÁM KHI THÊM CHU KỲ MỚI
-- ============================================================
DROP TRIGGER IF EXISTS trg_chuky_tao_lich ON "ChuKyTaiKham";
DROP FUNCTION IF EXISTS trg_fn_tao_lich_tai_kham();

CREATE OR REPLACE FUNCTION trg_fn_tao_lich_tai_kham()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW."TrangThai" = 'Đang hoạt động' THEN
        CALL sp_tao_lich_tai_kham(NEW."MaChuKy");
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_chuky_tao_lich
AFTER INSERT ON "ChuKyTaiKham"
FOR EACH ROW
EXECUTE FUNCTION trg_fn_tao_lich_tai_kham();

-- ============================================================
-- 7. PHÁT THUỐC KHI THANH TOÁN (TRỪ KHO, CẬP NHẬT ĐƠN)
-- ============================================================
DROP TRIGGER IF EXISTS trg_phat_thuoc ON "HoaDon";
DROP FUNCTION IF EXISTS fn_phat_thuoc();

CREATE OR REPLACE FUNCTION fn_phat_thuoc()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD."TrangThai" <> 'Đã thanh toán' AND NEW."TrangThai" = 'Đã thanh toán' THEN
        UPDATE "Thuoc" t
        SET "SoLuongTon" = t."SoLuongTon" - dt."SoLuong"
        FROM "DonThuoc" dt
        WHERE dt."MaBA" = NEW."MaBA" AND dt."MaThuoc" = t."MaThuoc";
        UPDATE "DonThuoc"
        SET "TrangThai" = 'Đã phát thuốc'
        WHERE "MaBA" = NEW."MaBA" AND "TrangThai" = 'Chờ phát thuốc';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_phat_thuoc
AFTER UPDATE ON "HoaDon"
FOR EACH ROW
WHEN (OLD."TrangThai" <> 'Đã thanh toán' AND NEW."TrangThai" = 'Đã thanh toán')
EXECUTE FUNCTION fn_phat_thuoc();

-- ============================================================
-- 8. GHI DOANH THU TIỀN KHÁM KHI TẠO HÓA ĐƠN
-- ============================================================
DROP TRIGGER IF EXISTS trg_hoadon_ghi_doanh_thu_kham ON "HoaDon";
DROP FUNCTION IF EXISTS fn_hoadon_ghi_doanh_thu_kham();

CREATE OR REPLACE FUNCTION fn_hoadon_ghi_doanh_thu_kham()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW."TienKham" > 0 THEN
        INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu", "NgayGhiNhan", "LoaiDoanhThu")
        VALUES (NEW."MaHD", NEW."TienKham", NEW."NgayXuat"::DATE, 'Tiền khám');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hoadon_ghi_doanh_thu_kham
AFTER INSERT ON "HoaDon"
FOR EACH ROW
EXECUTE FUNCTION fn_hoadon_ghi_doanh_thu_kham();

-- ============================================================
-- 9. GHI DOANH THU TIỀN THUỐC KHI THANH TOÁN
-- ============================================================
DROP TRIGGER IF EXISTS trg_hoadon_ghi_doanh_thu_thuoc ON "HoaDon";
DROP FUNCTION IF EXISTS fn_hoadon_ghi_doanh_thu_thuoc();

CREATE OR REPLACE FUNCTION fn_hoadon_ghi_doanh_thu_thuoc()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW."TrangThai" = 'Đã thanh toán' AND OLD."TrangThai" <> 'Đã thanh toán' THEN
        IF NEW."TienThuoc" > 0 THEN
            INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu", "NgayGhiNhan", "LoaiDoanhThu")
            VALUES (NEW."MaHD", NEW."TienThuoc", COALESCE(NEW."NgayThanhToan", CURRENT_DATE), 'Tiền thuốc');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_hoadon_ghi_doanh_thu_thuoc
AFTER UPDATE ON "HoaDon"
FOR EACH ROW
WHEN (NEW."TrangThai" = 'Đã thanh toán' AND OLD."TrangThai" <> 'Đã thanh toán')
EXECUTE FUNCTION fn_hoadon_ghi_doanh_thu_thuoc();