SET search_path TO quanly_phongkham, public;

CREATE OR REPLACE PROCEDURE sp_xu_ly_thuoc(
    p_hanh_dong VARCHAR(10),
    p_maBA INT,
    p_thuoc_cu VARCHAR(30),
    p_thuoc_moi VARCHAR(30) DEFAULT NULL,
    p_so_luong INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_thieu BOOLEAN;
BEGIN
    IF p_hanh_dong = 'thay' THEN
        IF p_so_luong IS NULL OR p_so_luong <= 0 THEN
            RAISE EXCEPTION 'Số lượng thuốc mới phải lớn hơn 0';
        END IF;
        IF p_thuoc_moi IS NULL THEN
            RAISE EXCEPTION 'Phải chỉ định thuốc mới khi thay';
        END IF;
        INSERT INTO "DonThuoc" ("MaBA", "MaThuoc", "SoLuong", "TrangThai")
        VALUES (p_maBA, p_thuoc_moi, p_so_luong, 'Chờ xử lý');
        DELETE FROM "DonThuoc" WHERE "MaBA" = p_maBA AND "MaThuoc" = p_thuoc_cu;
    ELSIF p_hanh_dong = 'xoa' THEN
        DELETE FROM "DonThuoc" WHERE "MaBA" = p_maBA AND "MaThuoc" = p_thuoc_cu;
    ELSE
        RAISE EXCEPTION 'Hành động không hợp lệ. Chỉ hỗ trợ ''thay'' hoặc ''xoa''';
    END IF;

    -- Kiểm tra tồn kho và cập nhật trạng thái
    SELECT EXISTS (
        SELECT 1
        FROM "DonThuoc" dt
        JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
        WHERE dt."MaBA" = p_maBA AND dt."SoLuong" > t."SoLuongTon"
    ) INTO v_thieu;

    UPDATE "DonThuoc"
    SET "TrangThai" = CASE WHEN v_thieu THEN 'Chờ xử lý' ELSE 'Chờ phát thuốc' END
    WHERE "MaBA" = p_maBA;
END;
$$;