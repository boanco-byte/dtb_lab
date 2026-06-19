SET search_path TO quanly_phongkham, public;

CREATE OR REPLACE PROCEDURE sp_thanh_toan_hoa_don(
    p_maHD INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBA INT;
    v_khong_du BOOLEAN;
BEGIN
    SELECT "MaBA" INTO v_maBA FROM "HoaDon" WHERE "MaHD" = p_maHD;

    -- Kiểm tra trạng thái đơn thuốc
    SELECT EXISTS (
        SELECT 1 FROM "DonThuoc" WHERE "MaBA" = v_maBA AND "TrangThai" <> 'Chờ phát thuốc'
    ) INTO v_khong_du;
    IF v_khong_du THEN
        RAISE EXCEPTION 'Đơn thuốc chưa sẵn sàng để phát.';
    END IF;

    -- Kiểm tra tồn kho
    SELECT EXISTS (
        SELECT 1
        FROM "DonThuoc" dt
        JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
        WHERE dt."MaBA" = v_maBA AND dt."SoLuong" > t."SoLuongTon"
    ) INTO v_khong_du;
    IF v_khong_du THEN
        RAISE EXCEPTION 'Không đủ tồn kho để xuất thuốc cho bệnh án %', v_maBA;
    END IF;

    -- Trừ tồn kho
    WITH tong_xuat AS (
        SELECT "MaThuoc", SUM("SoLuong") AS tong
        FROM "DonThuoc" WHERE "MaBA" = v_maBA GROUP BY "MaThuoc"
    )
    UPDATE "Thuoc" t
    SET "SoLuongTon" = t."SoLuongTon" - tong_xuat.tong
    FROM tong_xuat WHERE t."MaThuoc" = tong_xuat."MaThuoc";

    -- Cập nhật trạng thái đơn thuốc và hóa đơn
    UPDATE "DonThuoc" SET "TrangThai" = 'Đã phát thuốc' WHERE "MaBA" = v_maBA;
    UPDATE "HoaDon" SET "TrangThai" = 'Đã thanh toán' WHERE "MaHD" = p_maHD;

    -- Ghi doanh thu
    INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu")
    SELECT "MaHD", "TongTien" FROM "HoaDon" WHERE "MaHD" = p_maHD;
END;
$$;