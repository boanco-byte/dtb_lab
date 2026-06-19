SET search_path TO quanly_phongkham, public;

CREATE OR REPLACE PROCEDURE sp_dat_lich(
    p_maBN VARCHAR(20),
    p_thoigian TIMESTAMP,
    p_maBS VARCHAR(20) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_maBS VARCHAR(20);
    v_ketthuc TIMESTAMP := p_thoigian + INTERVAL '2 hour';
BEGIN
    IF p_maBS IS NOT NULL THEN
        SELECT bs."MaBS"
        INTO v_maBS
        FROM "BacSi" bs
        WHERE bs."MaBS" = p_maBS
          AND EXISTS (
              SELECT 1
              FROM "CaLamViec" c
              WHERE c."MaBS" = bs."MaBS"
                AND c."NgayLam" = DATE(p_thoigian)
                AND c."BatDau" <= CAST(p_thoigian AS TIME)
                AND c."KetThuc" >= CAST(v_ketthuc AS TIME)
          )
          AND NOT EXISTS (
              SELECT 1
              FROM "LichHen" lh
              WHERE lh."MaBS" = bs."MaBS"
                AND lh."TrangThai" NOT IN ('Đã hủy', 'Hoàn thành')
                AND NOT (
                    lh."ThoiGianKetThuc" <= p_thoigian
                    OR lh."ThoiGianBatDau" >= v_ketthuc
                )
          );
    END IF;

    IF v_maBS IS NULL THEN
        SELECT bs."MaBS"
        INTO v_maBS
        FROM "BacSi" bs
        WHERE EXISTS (
            SELECT 1
            FROM "CaLamViec" c
            WHERE c."MaBS" = bs."MaBS"
              AND c."NgayLam" = DATE(p_thoigian)
              AND c."BatDau" <= CAST(p_thoigian AS TIME)
              AND c."KetThuc" >= CAST(v_ketthuc AS TIME)
        )
        AND NOT EXISTS (
            SELECT 1
            FROM "LichHen" lh
            WHERE lh."MaBS" = bs."MaBS"
              AND lh."TrangThai" NOT IN ('Đã hủy', 'Hoàn thành')
              AND NOT (
                  lh."ThoiGianKetThuc" <= p_thoigian
                  OR lh."ThoiGianBatDau" >= v_ketthuc
              )
        )
        LIMIT 1;
    END IF;

    IF v_maBS IS NULL THEN
        RAISE EXCEPTION 'Không có bác sĩ phù hợp trong khung giờ yêu cầu.';
    END IF;

    INSERT INTO "LichHen"
        ("MaBN", "MaBS", "ThoiGianBatDau", "ThoiGianKetThuc")
    VALUES
        (p_maBN, v_maBS, p_thoigian, v_ketthuc);
END;
$$;