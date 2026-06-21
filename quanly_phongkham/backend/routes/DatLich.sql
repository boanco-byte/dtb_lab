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
    v_gio_batdau TIME := CAST(p_thoigian AS TIME);
    v_gio_ketthuc TIME := CAST(v_ketthuc AS TIME);
BEGIN
    -- 1. KIỂM TRA GIỜ LÀM VIỆC (8:00 - 17:00)
    IF v_gio_batdau < '08:00:00' OR v_gio_ketthuc > '17:00:00' THEN
        RAISE EXCEPTION 'Thời gian khám phải nằm trong khoảng 08:00 - 17:00';
    END IF;

    -- 2. KIỂM TRA BỆNH NHÂN ĐÃ CÓ LỊCH HẸN TRÙNG THỜI GIAN CHƯA
    IF EXISTS (
        SELECT 1
        FROM "LichHen" lh
        WHERE lh."MaBN" = p_maBN
          AND lh."TrangThai" NOT IN ('Đã hủy', 'Hoàn thành')
          AND NOT (
              lh."ThoiGianKetThuc" <= p_thoigian
              OR lh."ThoiGianBatDau" >= v_ketthuc
          )
    ) THEN
        RAISE EXCEPTION 'Bệnh nhân đã có lịch hẹn khác trong khoảng thời gian này. Vui lòng chọn giờ khác.';
    END IF;

    -- 3. NẾU CÓ CHỌN BÁC SĨ
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
                AND c."BatDau" <= v_gio_batdau
                AND c."KetThuc" >= v_gio_ketthuc
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

    -- 4. NẾU BÁC SĨ ĐƯỢC CHỌN BẬN HOẶC KHÔNG CHỌN -> TÌM BÁC SĨ KHÁC
    IF v_maBS IS NULL THEN
        SELECT bs."MaBS"
        INTO v_maBS
        FROM "BacSi" bs
        WHERE EXISTS (
            SELECT 1
            FROM "CaLamViec" c
            WHERE c."MaBS" = bs."MaBS"
              AND c."NgayLam" = DATE(p_thoigian)
              AND c."BatDau" <= v_gio_batdau
              AND c."KetThuc" >= v_gio_ketthuc
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
        RAISE EXCEPTION 'Không có bác sĩ rảnh trong khung giờ yêu cầu.';
    END IF;

    -- 5. CHÈN LỊCH HẸN
    INSERT INTO "LichHen"
        ("MaBN", "MaBS", "ThoiGianBatDau", "ThoiGianKetThuc")
    VALUES
        (p_maBN, v_maBS, p_thoigian, v_ketthuc);
END;
$$;