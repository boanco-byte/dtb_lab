SET search_path TO quanly_phongkham, public;

CREATE OR REPLACE FUNCTION trg_fn_cap_nhat_hoa_don()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
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
    SET
        "TienThuoc" = v_tien_thuoc,
        "TongTien" = "TienKham" + v_tien_thuoc
    WHERE "MaBA" = v_maBA;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_donthuoc_cap_nhat_hoadon
AFTER INSERT OR UPDATE OR DELETE ON "DonThuoc"
FOR EACH ROW
EXECUTE FUNCTION trg_fn_cap_nhat_hoa_don();