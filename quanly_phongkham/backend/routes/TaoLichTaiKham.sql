SET search_path TO quanly_phongkham, public;

-- Procedure tạo lịch tái khám
CREATE OR REPLACE PROCEDURE sp_tao_lich_tai_kham(
    p_maChuKy INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBN VARCHAR(20);
    v_maBS VARCHAR(20);
    v_ngay DATE;
    v_chuky INT;
    v_thoigian TIMESTAMP;
BEGIN
    SELECT "MaBN", "MaBS", "BatDau", "ChuKyNgay"
    INTO v_maBN, v_maBS, v_ngay, v_chuky
    FROM "ChuKyTaiKham"
    WHERE "MaChuKy" = p_maChuKy;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy chu kỳ %', p_maChuKy;
    END IF;

    v_thoigian := (v_ngay + (v_chuky || ' day')::INTERVAL) + TIME '08:00:00';

    CALL sp_dat_lich(v_maBN, v_thoigian, v_maBS);
END;
$$;

CREATE OR REPLACE FUNCTION trg_fn_tao_lich_tai_kham()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW."TrangThai" = 'Đang hoạt động' THEN
        CALL sp_tao_lich_tai_kham(NEW."MaChuKy");
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_chuky_tao_lich
AFTER INSERT ON "ChuKyTaiKham"
FOR EACH ROW
EXECUTE FUNCTION trg_fn_tao_lich_tai_kham();