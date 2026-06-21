SET search_path TO quanly_phongkham, public;

-- 1. Doanh thu theo ngày
CREATE OR REPLACE VIEW vw_doanh_thu_theo_ngay AS
SELECT
    "NgayGhiNhan",
    SUM(CASE WHEN "LoaiDoanhThu"='Tiền khám' THEN "DoanhThu" ELSE 0 END) AS "DoanhThuKham",
    SUM(CASE WHEN "LoaiDoanhThu"='Tiền thuốc' THEN "DoanhThu" ELSE 0 END) AS "DoanhThuThuoc",
    SUM("DoanhThu") AS "TongDoanhThu"
FROM "ChiTietDoanhThu"
GROUP BY "NgayGhiNhan"
ORDER BY "NgayGhiNhan";

-- 2. Doanh thu theo tháng
CREATE OR REPLACE VIEW vw_doanh_thu_theo_thang AS
SELECT
    EXTRACT(YEAR FROM "NgayGhiNhan") AS "Nam",
    EXTRACT(MONTH FROM "NgayGhiNhan") AS "Thang",
    SUM(CASE WHEN "LoaiDoanhThu"='Tiền khám' THEN "DoanhThu" ELSE 0 END) AS "DoanhThuKham",
    SUM(CASE WHEN "LoaiDoanhThu"='Tiền thuốc' THEN "DoanhThu" ELSE 0 END) AS "DoanhThuThuoc",
    SUM("DoanhThu") AS "TongDoanhThu"
FROM "ChiTietDoanhThu"
GROUP BY "Nam", "Thang"
ORDER BY "Nam", "Thang";

-- 3. Top thuốc được kê nhiều nhất
CREATE OR REPLACE VIEW vw_top_thuoc AS
SELECT
    t."MaThuoc", t."TenThuoc", SUM(dt."SoLuong") AS "TongSoLuongKe"
FROM "DonThuoc" dt
JOIN "Thuoc" t ON dt."MaThuoc" = t."MaThuoc"
GROUP BY t."MaThuoc", t."TenThuoc"
ORDER BY "TongSoLuongKe" DESC;

-- 4. Top bác sĩ có nhiều lượt khám hoàn thành nhất
CREATE OR REPLACE VIEW vw_top_bacsi AS
SELECT
    bs."MaBS", bs."HoTen", COUNT(*) AS "SoLuotKham"
FROM "LichHen" lh
JOIN "BacSi" bs ON lh."MaBS" = bs."MaBS"
WHERE lh."TrangThai" = 'Hoàn thành'
GROUP BY bs."MaBS", bs."HoTen"
ORDER BY "SoLuotKham" DESC;

-- 5. Thuốc sắp hết (tồn kho < 20)
CREATE OR REPLACE VIEW vw_thuoc_sap_het AS
SELECT "MaThuoc", "TenThuoc", "SoLuongTon"
FROM "Thuoc"
WHERE "SoLuongTon" < 20
ORDER BY "SoLuongTon";

-- 6. Thống kê số lượng lịch hẹn theo trạng thái
CREATE OR REPLACE VIEW vw_thong_ke_lich_hen AS
SELECT "TrangThai", COUNT(*) AS "SoLuong"
FROM "LichHen"
GROUP BY "TrangThai"
ORDER BY "SoLuong" DESC;

-- 7. Top bệnh nhân có nhiều chu kỳ tái khám nhất
CREATE OR REPLACE VIEW vw_top_taikham AS
SELECT
    bn."MaBN", bn."HoTen", COUNT(*) AS "SoLanTaiKham"
FROM "ChuKyTaiKham" ck
JOIN "BenhNhan" bn ON bn."MaBN" = ck."MaBN"
GROUP BY bn."MaBN", bn."HoTen"
ORDER BY "SoLanTaiKham" DESC;

-- 8. Tồn kho tổng hợp
CREATE OR REPLACE VIEW vw_ton_kho AS
SELECT "MaThuoc", "TenThuoc", "DonVi", "SoLuongTon"
FROM "Thuoc"
ORDER BY "TenThuoc";