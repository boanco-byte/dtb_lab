SET search_path TO quanly_phongkham, public;

-- Xóa dữ liệu cũ (nếu muốn reset)
TRUNCATE TABLE "ChiTietDoanhThu" CASCADE;
TRUNCATE TABLE "HoaDon" CASCADE;
TRUNCATE TABLE "DonThuoc" CASCADE;
TRUNCATE TABLE "BenhAn" CASCADE;
TRUNCATE TABLE "LichHen" CASCADE;
TRUNCATE TABLE "ChuKyTaiKham" CASCADE;
TRUNCATE TABLE "ThietLapNhacNho" CASCADE;
TRUNCATE TABLE "LichSuNhacNho" CASCADE;
TRUNCATE TABLE "NhacNho" CASCADE;
TRUNCATE TABLE "LoiNhac" CASCADE;
TRUNCATE TABLE "PhongKham" CASCADE;
TRUNCATE TABLE "BenhNhan" CASCADE;
TRUNCATE TABLE "BacSi" CASCADE;
TRUNCATE TABLE "CaLamViec" CASCADE;
TRUNCATE TABLE "TaiKhoanBenhNhan" CASCADE;
TRUNCATE TABLE "Thuoc" CASCADE;

-- Reset sequences
ALTER SEQUENCE "LichHen_MaLH_seq" RESTART WITH 1;
ALTER SEQUENCE "BenhAn_MaBA_seq" RESTART WITH 1;
ALTER SEQUENCE "DonThuoc_MaDon_seq" RESTART WITH 1;
ALTER SEQUENCE "HoaDon_MaHD_seq" RESTART WITH 1;
ALTER SEQUENCE "ChiTietDoanhThu_MaDT_seq" RESTART WITH 1;
ALTER SEQUENCE "ChuKyTaiKham_MaChuKy_seq" RESTART WITH 1;
ALTER SEQUENCE "NhacNho_MaNN_seq" RESTART WITH 1;


DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM "PhongKham" WHERE "MaPK" = 1) THEN
        INSERT INTO "PhongKham" ("MaPK", "TenPhong") VALUES (1, 'Phòng khám Mắt - Nhãn khoa');
    END IF;
END;
$$;
-- ============================================================
-- Tạo dữ liệu test lớn: 20 bác sĩ, 100 thuốc, 1000 bệnh nhân
-- ============================================================

-- 0. Tạo phòng khám nếu chưa có
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM "PhongKham" WHERE "MaPK" = 1) THEN
        INSERT INTO "PhongKham" ("MaPK", "TenPhong") VALUES (1, 'Phòng khám Mắt - Nhãn khoa');
        RAISE NOTICE 'Đã tạo phòng khám MaPK=1';
    END IF;
END;
$$;

-- 1. Thêm 20 bác sĩ (nếu chưa có)
DO $$
DECLARE
    i INT;
    v_maBS TEXT;
    v_ho_ten TEXT;
    v_sdt TEXT;
    v_ten_list TEXT[] := ARRAY['Nguyễn','Trần','Lê','Phạm','Hoàng','Vũ','Đặng','Bùi','Đỗ','Hồ','Võ','Ngô','Trương','Lý','Thái','Phan','Đinh','Tăng','Triệu','Mạc'];
    v_dem_list TEXT[] := ARRAY['Văn','Thị','Hữu','Minh','Quang','Thu','Hà','Tùng','Duy','Bảo','Thành','Hùng','Dũng','Cường','Anh','Phương','Thuỷ','Hương','Tú','Quyên'];
    v_ten_list2 TEXT[] := ARRAY['Anh','Bình','Cường','Dũng','Đạt','Hoa','Hương','Khánh','Linh','Mai','Phúc','Quân','Sơn','Tâm','Vân','Yến','Đức','Khoa','My','Nhi'];
BEGIN
    FOR i IN 1..20 LOOP
        v_maBS := 'BS' || LPAD(i::TEXT, 3, '0');
        IF NOT EXISTS (SELECT 1 FROM "BacSi" WHERE "MaBS" = v_maBS) THEN
            v_ho_ten := v_ten_list[floor(random()*array_length(v_ten_list,1))+1] || ' ' ||
                         v_dem_list[floor(random()*array_length(v_dem_list,1))+1] || ' ' ||
                         v_ten_list2[floor(random()*array_length(v_ten_list2,1))+1];
            v_sdt := '0' || (100000000 + floor(random()*900000000))::TEXT;
            INSERT INTO "BacSi" ("MaBS", "HoTen", "SDT", "MaPK")
            VALUES (v_maBS, v_ho_ten, v_sdt, 1);
        END IF;
    END LOOP;
    RAISE NOTICE 'Đã thêm bác sĩ (nếu chưa có).';
END;
$$;

-- 2. Thêm 100 loại thuốc (nếu chưa có)
DO $$
DECLARE
    i INT;
    v_maThuoc TEXT;
    v_ten_thuoc TEXT;
    v_don_vi TEXT;
    v_don_gia DECIMAL(10,2);
    v_ton_kho INT;
    v_nha_sx TEXT;
    v_ten_thuoc_list TEXT[] := ARRAY[
        'Paracetamol','Amoxicillin','Ciprofloxacin','Azithromycin','Ofloxacin','Tobramycin','Dorzolamide','Prednisolone',
        'Natri Clorid','Dexamethasone','Moxifloxacin','Levofloxacin','Gentamicin','Cefalexin','Ceftriaxone',
        'Metronidazole','Omeprazole','Clarithromycin','Ibuprofen','Diclofenac','Indomethacin','Atropine',
        'Pilocarpine','Timolol','Latanoprost','Bimatoprost','Travoprost','Ketorolac','Nepafenac','Bromfenac',
        'Flurbiprofen','Rimexolone','Loteprednol','Fluorometholone','Cyclosporine','Tacrolimus','Sodium Hyaluronate',
        'Carboxymethylcellulose','Hypromellose','Polyvinyl Alcohol','Povidone','Chloramphenicol','Neomycin',
        'Polymyxin B','Bacitracin','Fusidic Acid','Linezolid','Vancomycin','Teicoplanin','Daptomycin',
        'Colistin','Tigecycline','Ertapenem','Imipenem','Meropenem','Doripenem','Aztreonam','Cefepime',
        'Cefotaxime','Ceftazidime','Ceftriaxone','Cefuroxime','Cefaclor','Cefixime','Cefpodoxime','Cefdinir',
        'Cefditoren','Ceftibuten','Cefprozil','Cefadroxil','Cephalexin','Cephradine','Cephapirin',
        'Amoxicillin-Clavulanate','Ampicillin','Penicillin V','Penicillin G','Oxacillin','Cloxacillin',
        'Dicloxacillin','Nafcillin','Methicillin','Piperacillin','Ticarcillin','Mezlocillin','Azlocillin',
        'Carbenicillin','Temocillin','Sulbactam','Tazobactam','Clavulanate','Avibactam','Vaborbactam',
        'Relebactam','Cefiderocol','Fosfomycin','Fusidic Acid','Mupirocin','Retapamulin','Ozenoxacin'
    ];
    v_don_vi_list TEXT[] := ARRAY['Viên','Lọ','Ống','Chai','Gói','Tuýp'];
    v_nha_sx_list TEXT[] := ARRAY['DHG','Imexpharm','Sanofi','Pharmedic','Fresenius','AstraZeneca','Pfizer','Novartis','Roche','MSD'];
BEGIN
    FOR i IN 1..100 LOOP
        v_maThuoc := 'T' || LPAD(i::TEXT, 3, '0');
        IF NOT EXISTS (SELECT 1 FROM "Thuoc" WHERE "MaThuoc" = v_maThuoc) THEN
            v_ten_thuoc := v_ten_thuoc_list[i];
            v_don_vi := v_don_vi_list[floor(random()*array_length(v_don_vi_list,1))+1];
            v_don_gia := (5000 + random()*50000)::DECIMAL(10,2);
            v_ton_kho := floor(random()*200) + 10;
            v_nha_sx := v_nha_sx_list[floor(random()*array_length(v_nha_sx_list,1))+1];
            INSERT INTO "Thuoc" ("MaThuoc", "TenThuoc", "DonVi", "DonGia", "SoLuongTon", "NhaSX")
            VALUES (v_maThuoc, v_ten_thuoc, v_don_vi, v_don_gia, v_ton_kho, v_nha_sx);
        END IF;
    END LOOP;
    RAISE NOTICE 'Đã thêm thuốc (nếu chưa có).';
END;
$$;

-- 3. Tạo bệnh nhân mới (nếu chưa đủ 1000)
DO $$
DECLARE
    v_current_count INT;
    v_target_count INT := 1000;
    v_maBN TEXT;
    v_ho_ten TEXT;
    v_ngay_sinh DATE;
    v_gioi_tinh TEXT;
    v_sdt TEXT;
    i INT;
    v_ten_list TEXT[] := ARRAY['Nguyễn','Trần','Lê','Phạm','Hoàng','Vũ','Đặng','Bùi','Đỗ','Hồ','Võ','Ngô','Trương','Lý','Thái','Phan','Đinh','Tăng','Triệu','Mạc'];
    v_dem_list TEXT[] := ARRAY['Văn','Thị','Hữu','Minh','Quang','Thu','Hà','Tùng','Duy','Bảo','Thành','Hùng','Dũng','Cường','Anh','Phương','Thuỷ','Hương','Tú','Quyên'];
    v_ten_list2 TEXT[] := ARRAY['Anh','Bình','Cường','Dũng','Đạt','Hoa','Hương','Khánh','Linh','Mai','Phúc','Quân','Sơn','Tâm','Vân','Yến','Đức','Khoa','My','Nhi'];
BEGIN
    SELECT COUNT(*) INTO v_current_count FROM "BenhNhan";
    IF v_current_count < v_target_count THEN
        FOR i IN (v_current_count+1)..v_target_count LOOP
            v_maBN := 'BN' || LPAD(i::TEXT, 5, '0');
            v_ho_ten := v_ten_list[floor(random()*array_length(v_ten_list,1))+1] || ' ' ||
                         v_dem_list[floor(random()*array_length(v_dem_list,1))+1] || ' ' ||
                         v_ten_list2[floor(random()*array_length(v_ten_list2,1))+1];
            v_ngay_sinh := CURRENT_DATE - (random() * 80 * 365)::INT;
            v_gioi_tinh := (ARRAY['Nam','Nữ','Khác'])[floor(random()*3)+1];
            v_sdt := '0' || (100000000 + floor(random()*900000000))::TEXT;
            INSERT INTO "BenhNhan" ("MaBN", "HoTen", "NgaySinh", "GioiTinh", "SDT")
            VALUES (v_maBN, v_ho_ten, v_ngay_sinh, v_gioi_tinh, v_sdt);
        END LOOP;
        RAISE NOTICE 'Đã thêm % bệnh nhân mới.', v_target_count - v_current_count;
    ELSE
        RAISE NOTICE 'Đã có đủ % bệnh nhân.', v_current_count;
    END IF;
END;
$$;

-- 4. Tạo lịch hẹn (từ năm 2025) với kiểm tra trùng ca
DO $$
DECLARE
    v_benh_nhan RECORD;
    v_so_lich INT;
    v_ngay DATE;
    v_batdau TIMESTAMP;
    v_ketthuc TIMESTAMP;
    v_ca INT;
    v_maBS TEXT;
    v_trangthai TEXT;
    v_max_attempts INT := 200;
    v_attempt INT;
    v_inserted BOOLEAN;
    v_bac_si_list TEXT[];
    v_benh_nhan_cursor CURSOR FOR 
        SELECT "MaBN" FROM "BenhNhan" 
        ORDER BY "MaBN" 
        LIMIT 1000;
BEGIN
    SELECT ARRAY_AGG("MaBS") INTO v_bac_si_list FROM "BacSi";
    IF array_length(v_bac_si_list,1) IS NULL THEN
        RAISE EXCEPTION 'Chưa có bác sĩ nào để tạo lịch hẹn!';
    END IF;

    FOR v_benh_nhan IN v_benh_nhan_cursor LOOP
        v_so_lich := floor(random() * 6)::INT; -- 0-5 lịch
        FOR i IN 1..v_so_lich LOOP
            v_attempt := 0;
            v_inserted := FALSE;
            WHILE v_attempt < v_max_attempts AND NOT v_inserted LOOP
                v_attempt := v_attempt + 1;
                -- Ngày từ 01/01/2025 đến 31/12/2025
                v_ngay := DATE '2025-01-01' + (random() * 364)::INT;
                v_ca := floor(random() * 6) + 1;
                v_batdau := v_ngay + (CASE v_ca
                    WHEN 1 THEN TIME '08:00'
                    WHEN 2 THEN TIME '09:30'
                    WHEN 3 THEN TIME '11:00'
                    WHEN 4 THEN TIME '13:00'
                    WHEN 5 THEN TIME '14:30'
                    WHEN 6 THEN TIME '16:00'
                END);
                v_ketthuc := v_batdau + INTERVAL '1.5 hours';
                v_maBS := v_bac_si_list[floor(random()*array_length(v_bac_si_list,1))+1];
                v_trangthai := CASE floor(random()*10)
                    WHEN 0 THEN 'Đã hủy'
                    WHEN 1 THEN 'Đang khám'
                    WHEN 2 THEN 'Đang khám'
                    WHEN 3 THEN 'Chờ khám'
                    WHEN 4 THEN 'Chờ khám'
                    ELSE 'Đã khám'
                END;

                -- Chỉ insert nếu lịch đã khám/hủy hoặc thời gian bắt đầu chưa qua (đối với chờ/đang khám)
                IF v_trangthai IN ('Đã khám', 'Đã hủy') OR v_batdau > NOW() THEN
                    IF v_trangthai IN ('Chờ khám', 'Đang khám') THEN
                        -- Kiểm tra trùng ca của bác sĩ
                        IF NOT EXISTS (
                            SELECT 1 FROM "LichHen" lh
                            WHERE lh."MaBS" = v_maBS
                              AND DATE(lh."ThoiGianBatDau") = v_ngay
                              AND lh."CaSo" = v_ca
                              AND lh."TrangThai" IN ('Chờ khám', 'Đang khám')
                        ) THEN
                            INSERT INTO "LichHen" ("MaBN", "MaBS", "CaSo", "ThoiGianBatDau", "ThoiGianKetThuc", "TrangThai")
                            VALUES (v_benh_nhan."MaBN", v_maBS, v_ca, v_batdau, v_ketthuc, v_trangthai);
                            v_inserted := TRUE;
                        END IF;
                    ELSE
                        -- Lịch đã khám hoặc hủy: không cần kiểm tra trùng
                        INSERT INTO "LichHen" ("MaBN", "MaBS", "CaSo", "ThoiGianBatDau", "ThoiGianKetThuc", "TrangThai")
                        VALUES (v_benh_nhan."MaBN", v_maBS, v_ca, v_batdau, v_ketthuc, v_trangthai);
                        v_inserted := TRUE;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Đã tạo lịch hẹn.';
END;
$$;

-- 5. Tạo bệnh án cho lịch đã khám (chọn random 80%)
DO $$
BEGIN
    INSERT INTO "BenhAn" ("MaLH", "ChanDoan", "TrieuChung", "GhiChu", "NgayTao")
    SELECT 
        lh."MaLH",
        (ARRAY[
            'Viêm kết mạc cấp','Cận thị','Viễn thị','Loạn thị','Đục thủy tinh thể',
            'Glaucoma','Hội chứng khô mắt','Dị ứng mắt','Viêm giác mạc',
            'Xuất huyết dịch kính','Bong võng mạc','Thoái hóa điểm vàng',
            'Viêm màng bồ đào','Viêm dây thần kinh thị giác','U mắt'
        ])[floor(random()*15)+1] AS "ChanDoan",
        (ARRAY[
            'Đỏ mắt, ngứa, chảy nước mắt','Nhìn mờ khi nhìn xa, mỏi mắt',
            'Nhìn gần kém, mỏi mắt','Nhìn vật bị méo, mỏi mắt',
            'Nhìn mờ, nhạy cảm ánh sáng','Đau mắt, nhìn mờ, nhức đầu',
            'Cảm giác cộm, khô mắt','Ngứa, đỏ mắt, chảy nước mắt',
            'Đau mắt, nhìn mờ, sợ ánh sáng','Nhìn thấy bóng đen, mất thị lực đột ngột'
        ])[floor(random()*10)+1] AS "TrieuChung",
        'Đã kê đơn thuốc' AS "GhiChu",
        lh."ThoiGianBatDau"::DATE AS "NgayTao"
    FROM "LichHen" lh
    WHERE lh."TrangThai" = 'Đã khám'
      AND NOT EXISTS (SELECT 1 FROM "BenhAn" WHERE "MaLH" = lh."MaLH")
    ORDER BY random()
    LIMIT (SELECT COUNT(*) FROM "LichHen" WHERE "TrangThai" = 'Đã khám') * 0.8;
    RAISE NOTICE 'Đã tạo bệnh án.';
END;
$$;

-- 6. Tạo đơn thuốc cho bệnh án (mỗi bệnh án 1-3 thuốc)
DO $$
DECLARE
    v_ba RECORD;
    v_so_thuoc INT;
    v_thuoc_list TEXT[];
    v_lieu_dung_list TEXT[] := ARRAY['1 giọt x 3 lần/ngày', '2 giọt x 4 lần/ngày', '1 viên x 2 lần/ngày', '2 viên x 3 lần/ngày'];
    v_huong_dan_list TEXT[] := ARRAY['Uống sau ăn', 'Nhỏ mắt', 'Uống trước ăn', 'Nhỏ mắt trước khi ngủ'];
BEGIN
    SELECT ARRAY_AGG("MaThuoc") INTO v_thuoc_list FROM "Thuoc";
    IF array_length(v_thuoc_list,1) IS NULL THEN
        RAISE EXCEPTION 'Chưa có thuốc nào để tạo đơn!';
    END IF;

    FOR v_ba IN (SELECT "MaBA" FROM "BenhAn") LOOP
        v_so_thuoc := floor(random() * 3) + 1; -- 1-3 thuốc
        FOR i IN 1..v_so_thuoc LOOP
            INSERT INTO "DonThuoc" ("MaBA", "MaThuoc", "SoLuong", "LieuDung", "HuongDan", "TrangThai")
            VALUES (
                v_ba."MaBA",
                v_thuoc_list[floor(random()*array_length(v_thuoc_list,1))+1],
                floor(random()*5)+1,
                v_lieu_dung_list[floor(random()*array_length(v_lieu_dung_list,1))+1],
                v_huong_dan_list[floor(random()*array_length(v_huong_dan_list,1))+1],
                'Chờ xử lý'
            );
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Đã tạo đơn thuốc.';
END;
$$;

-- 7. Tạo hóa đơn cho bệnh án (mỗi bệnh án 1 hóa đơn)
DO $$
BEGIN
    INSERT INTO "HoaDon" ("MaBA", "NgayXuat", "TienKham", "PhuongThuc", "TrangThai")
    SELECT 
        ba."MaBA",
        ba."NgayTao" + (random()*5)::INT AS "NgayXuat",
        (100000 + random()*200000)::DECIMAL(12,2) AS "TienKham",
        (ARRAY['Tiền mặt', 'Chuyển khoản QR', 'Thẻ POS'])[floor(random()*3)+1] AS "PhuongThuc",
        (CASE WHEN random() < 0.6 THEN 'Đã thanh toán' ELSE 'Chưa thanh toán' END) AS "TrangThai"
    FROM "BenhAn" ba
    WHERE NOT EXISTS (SELECT 1 FROM "HoaDon" WHERE "MaBA" = ba."MaBA");
    RAISE NOTICE 'Đã tạo hóa đơn.';
END;
$$;

-- 8. Cập nhật tiền thuốc và tổng tiền cho hóa đơn
DO $$
DECLARE
    v_hd RECORD;
    v_tienthuoc DECIMAL(12,2);
BEGIN
    FOR v_hd IN (SELECT "MaHD", "MaBA" FROM "HoaDon") LOOP
        SELECT COALESCE(SUM(dt."SoLuong" * t."DonGia"), 0) INTO v_tienthuoc
        FROM "DonThuoc" dt
        JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
        WHERE dt."MaBA" = v_hd."MaBA";
        UPDATE "HoaDon"
        SET "TienThuoc" = v_tienthuoc,
            "TongTien" = "TienKham" + v_tienthuoc
        WHERE "MaHD" = v_hd."MaHD";
    END LOOP;
    RAISE NOTICE 'Đã cập nhật tiền thuốc và tổng tiền.';
END;
$$;

-- 9. Ghi doanh thu cho hóa đơn đã thanh toán
DO $$
BEGIN
    INSERT INTO "ChiTietDoanhThu" ("MaHD", "DoanhThu", "NgayGhiNhan")
    SELECT 
        "MaHD",
        "TongTien",
        "NgayXuat"::DATE
    FROM "HoaDon"
    WHERE "TrangThai" = 'Đã thanh toán'
      AND NOT EXISTS (SELECT 1 FROM "ChiTietDoanhThu" WHERE "MaHD" = "HoaDon"."MaHD");
    RAISE NOTICE 'Đã ghi doanh thu.';
END;
$$;

-- ============================================================
-- 10. Tạo chu kỳ tái khám (TẮT TRIGGER để tránh lỗi quá khứ)
-- ============================================================
DO $$
DECLARE
    v_bn RECORD;
    v_bac_si_list TEXT[];
    v_bs TEXT;
    v_ngay_batdau DATE;
BEGIN
    -- Tắt trigger tạo lịch tái khám tự động
    ALTER TABLE "ChuKyTaiKham" DISABLE TRIGGER trg_chuky_tao_lich;
    RAISE NOTICE 'Đã tắt trigger trg_chuky_tao_lich.';

    SELECT ARRAY_AGG("MaBS") INTO v_bac_si_list FROM "BacSi";
    IF array_length(v_bac_si_list,1) IS NOT NULL THEN
        FOR v_bn IN (SELECT "MaBN" FROM "BenhNhan" ORDER BY random() LIMIT 100) LOOP
            v_bs := v_bac_si_list[floor(random()*array_length(v_bac_si_list,1))+1];
            -- Ngày bắt đầu từ ngày hiện tại trở đi (không để quá khứ)
            v_ngay_batdau := CURRENT_DATE + (random() * 30)::INT;
            IF NOT EXISTS (SELECT 1 FROM "ChuKyTaiKham" WHERE "MaBN" = v_bn."MaBN" AND "TrangThai" = 'Đang hoạt động') THEN
                INSERT INTO "ChuKyTaiKham" ("MaBN", "MaBS", "ChuKyNgay", "BatDau", "KetThuc", "TrangThai")
                VALUES (
                    v_bn."MaBN",
                    v_bs,
                    30,
                    v_ngay_batdau,
                    v_ngay_batdau + 180,
                    'Đang hoạt động'
                );
            END IF;
        END LOOP;
    END IF;

    -- Bật lại trigger
    ALTER TABLE "ChuKyTaiKham" ENABLE TRIGGER trg_chuky_tao_lich;
    RAISE NOTICE 'Đã bật lại trigger trg_chuky_tao_lich.';
END;
$$;

-- ============================================================
-- 11. Thống kê số lượng
-- ============================================================
SELECT '👤 Bệnh nhân' AS "Loại", COUNT(*) AS "Số lượng" FROM "BenhNhan"
UNION ALL
SELECT '👨‍⚕️ Bác sĩ', COUNT(*) FROM "BacSi"
UNION ALL
SELECT '💊 Thuốc', COUNT(*) FROM "Thuoc"
UNION ALL
SELECT '📅 Lịch hẹn', COUNT(*) FROM "LichHen"
UNION ALL
SELECT '🧾 Bệnh án', COUNT(*) FROM "BenhAn"
UNION ALL
SELECT '💊 Đơn thuốc', COUNT(*) FROM "DonThuoc"
UNION ALL
SELECT '💳 Hóa đơn', COUNT(*) FROM "HoaDon"
UNION ALL
SELECT '💰 Doanh thu', COUNT(*) FROM "ChiTietDoanhThu"
UNION ALL
SELECT '📆 Chu kỳ tái khám', COUNT(*) FROM "ChuKyTaiKham";