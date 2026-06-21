-- Tạo schema nếu chưa có
CREATE SCHEMA IF NOT EXISTS quanly_phongkham;
SET search_path TO quanly_phongkham, public;

-- Xóa tất cả bảng cũ (nếu muốn reset)
DROP TABLE IF EXISTS "LichSuNhacNho" CASCADE;
DROP TABLE IF EXISTS "MauLoiNhac" CASCADE;
DROP TABLE IF EXISTS "ThietLapNhacNho" CASCADE;
DROP TABLE IF EXISTS "LoiNhac" CASCADE;
DROP TABLE IF EXISTS "NhacNho" CASCADE;
DROP TABLE IF EXISTS "ChiTietDoanhThu" CASCADE;
DROP TABLE IF EXISTS "HoaDon" CASCADE;
DROP TABLE IF EXISTS "DonThuoc" CASCADE;
DROP TABLE IF EXISTS "Thuoc" CASCADE;
DROP TABLE IF EXISTS "BenhAn" CASCADE;
DROP TABLE IF EXISTS "ChuKyTaiKham" CASCADE;
DROP TABLE IF EXISTS "LichHen" CASCADE;
DROP TABLE IF EXISTS "CaLamViec" CASCADE;
DROP TABLE IF EXISTS "TaiKhoanBenhNhan" CASCADE;
DROP TABLE IF EXISTS "BacSi" CASCADE;
DROP TABLE IF EXISTS "PhongKham" CASCADE;
DROP TABLE IF EXISTS "BenhNhan" CASCADE;

CREATE TABLE "BenhNhan" (
    "MaBN" VARCHAR(20) PRIMARY KEY,
    "HoTen" VARCHAR(100) NOT NULL,
    "NgaySinh" DATE,
    "GioiTinh" VARCHAR(10) NOT NULL,
    "SDT" VARCHAR(15)
);

CREATE TABLE "PhongKham" (
    "MaPK" INT PRIMARY KEY,
    "TenPhong" VARCHAR(100) NOT NULL
);

CREATE TABLE "BacSi" (
    "MaBS" VARCHAR(20) PRIMARY KEY,
    "HoTen" VARCHAR(100) NOT NULL,
    "SDT" VARCHAR(15),
    "MaPK" INT REFERENCES "PhongKham"("MaPK") ON DELETE SET NULL
);

CREATE TABLE "CaLamViec" (
    "MaCa" SERIAL PRIMARY KEY,
    "MaBS" VARCHAR(20) NOT NULL REFERENCES "BacSi"("MaBS") ON DELETE CASCADE,
    "NgayLam" DATE NOT NULL,
    "BatDau" TIME NOT NULL,
    "KetThuc" TIME NOT NULL,
    CHECK ("BatDau" < "KetThuc")
);

CREATE TABLE "LichHen" (
    "MaLH" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaBS" VARCHAR(20) NOT NULL REFERENCES "BacSi"("MaBS") ON DELETE CASCADE,
	"CaSo" INT NOT NULL DEFAULT 1,
    "ThoiGianBatDau" TIMESTAMP NOT NULL,
    "ThoiGianKetThuc" TIMESTAMP NOT NULL,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chờ khám'
);

CREATE TABLE "ChuKyTaiKham" (
    "MaChuKy" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaBS" VARCHAR(20) REFERENCES "BacSi"("MaBS") ON DELETE SET NULL,
    "ChuKyNgay" INT NOT NULL DEFAULT 30,
    "BatDau" DATE NOT NULL DEFAULT CURRENT_DATE,
    "KetThuc" DATE,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Đang hoạt động'
);

CREATE TABLE "BenhAn" (
    "MaBA" SERIAL PRIMARY KEY,
    "MaLH" INT REFERENCES "LichHen"("MaLH") ON DELETE SET NULL,
    "ThoiGianVao" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ChanDoan" TEXT NOT NULL,
    "TrieuChung" TEXT,
    "GhiChu" TEXT,
    "NgayTao" DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE "Thuoc" (
    "MaThuoc" VARCHAR(30) PRIMARY KEY,
    "TenThuoc" VARCHAR(100) NOT NULL,
    "DonVi" VARCHAR(20) NOT NULL DEFAULT 'Viên',
    "TenKho" VARCHAR(50) DEFAULT 'Kho chính',
    "NhaSX" VARCHAR(100),
    "DonGia" DECIMAL(10, 2) NOT NULL,
    "SoLuongTon" INT NOT NULL DEFAULT 0
);

CREATE TABLE "DonThuoc" (
    "MaDon" SERIAL PRIMARY KEY,
    "MaBA" INT NOT NULL REFERENCES "BenhAn"("MaBA") ON DELETE CASCADE,
    "MaThuoc" VARCHAR(30) NOT NULL REFERENCES "Thuoc"("MaThuoc") ON DELETE RESTRICT,
    "SoLuong" INT NOT NULL,
    "LieuDung" VARCHAR(150),
    "HuongDan" TEXT,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chờ xử lý'
);

CREATE TABLE "HoaDon" (
    "MaHD" SERIAL PRIMARY KEY,
    "MaBA" INT NOT NULL REFERENCES "BenhAn"("MaBA") ON DELETE CASCADE,
    "NgayXuat" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "NgayThanhToan" DATE, -- Ngày thực tế thanh toán
    "PhuongThuc" VARCHAR(50) NOT NULL DEFAULT 'Tiền mặt',
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chưa thanh toán',
    "TongTien" DECIMAL(12, 2) NOT NULL DEFAULT 0,
    "TienKham" DECIMAL(12, 2) NOT NULL DEFAULT 0,
    "TienThuoc" DECIMAL(12, 2) NOT NULL DEFAULT 0
);

CREATE TABLE "ChiTietDoanhThu" (
    "MaDT" SERIAL PRIMARY KEY,
    "MaHD" INT NOT NULL REFERENCES "HoaDon"("MaHD") ON DELETE CASCADE,
    "DoanhThu" DECIMAL(12, 2) NOT NULL,
    "NgayGhiNhan" DATE NOT NULL DEFAULT CURRENT_DATE,
    "LoaiDoanhThu" VARCHAR(20)
);

CREATE TABLE "TaiKhoanBenhNhan" (
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MatKhauHash" VARCHAR(255) NOT NULL,
    PRIMARY KEY ("MaBN")
);

CREATE TABLE "ThietLapNhacNho" (
    "MaThietLap" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaChuKy" INT REFERENCES "ChuKyTaiKham"("MaChuKy") ON DELETE CASCADE,
    "MaLH" INT REFERENCES "LichHen"("MaLH") ON DELETE CASCADE,
    "SoNgayTruoc" INT NOT NULL DEFAULT 1,
    "Kenh" VARCHAR(20) NOT NULL DEFAULT 'sms',
    "TrangThai" VARCHAR(50) DEFAULT 'Đang hoạt động',
    CONSTRAINT "chk_kenh" CHECK ("Kenh" IN ('sms', 'email', 'app_push')),
    CONSTRAINT "chk_trangthai_thietlap" CHECK ("TrangThai" IN ('Đang hoạt động', 'Tạm dừng', 'Đã hủy')),
    CONSTRAINT "chk_co_ma_lich_hoac_chuky" CHECK (
        ("MaLH" IS NOT NULL AND "MaChuKy" IS NULL) OR
        ("MaChuKy" IS NOT NULL AND "MaLH" IS NULL)
    )
);

CREATE TABLE "MauLoiNhac" (
    "MaMau" SERIAL PRIMARY KEY,
    "TenMau" VARCHAR(100) NOT NULL,
    "NoiDung" TEXT NOT NULL,
    "Loai" VARCHAR(50) NOT NULL,
    "Kenh" VARCHAR(20) DEFAULT 'sms'
);

CREATE TABLE "LichSuNhacNho" (
    "MaLS" SERIAL PRIMARY KEY,
    "MaThietLap" INT NOT NULL REFERENCES "ThietLapNhacNho"("MaThietLap") ON DELETE CASCADE,
    "ThoiGianGui" TIMESTAMP NOT NULL DEFAULT NOW(),
    "NoiDung" TEXT NOT NULL,
    "TrangThai" VARCHAR(50) DEFAULT 'Đã gửi',
    "GhiChu" TEXT,
    CONSTRAINT "chk_trangthai_log" CHECK ("TrangThai" IN ('Đã gửi', 'Lỗi', 'Chưa gửi'))
);

CREATE TABLE "NhacNho" (
    "MaNN" SERIAL PRIMARY KEY,
    "MaBN" VARCHAR(20) NOT NULL REFERENCES "BenhNhan"("MaBN") ON DELETE CASCADE,
    "MaChuKy" INT NOT NULL REFERENCES "ChuKyTaiKham"("MaChuKy") ON DELETE CASCADE,
    "SoLuong" INT NOT NULL DEFAULT 0
);

CREATE TABLE "LoiNhac" (
    "MaNN" INT NOT NULL REFERENCES "NhacNho"("MaNN") ON DELETE CASCADE,
    "ThoiGianGui" TIMESTAMP NOT NULL,
    "TrangThai" VARCHAR(50) NOT NULL DEFAULT 'Chưa gửi',
    PRIMARY KEY ("MaNN", "ThoiGianGui")
);

ALTER TABLE "BenhNhan" ADD CONSTRAINT "chk_benhnhan_gioitinh" CHECK ("GioiTinh" IN ('Nam', 'Nữ', 'Khác'));
ALTER TABLE "BenhNhan" ADD CONSTRAINT "chk_benhnhan_sdt" CHECK ("SDT" ~ '^0[0-9]{8,10}$');

ALTER TABLE "BacSi" ADD CONSTRAINT "chk_bacsi_sdt" CHECK ("SDT" ~ '^0[0-9]{8,10}$');

ALTER TABLE "LichHen" ADD CONSTRAINT "chk_lichhen_trangthai" CHECK ("TrangThai" IN ('Chờ khám', 'Đang khám', 'Đã khám', 'Đã hủy'));
ALTER TABLE "LichHen" ADD CONSTRAINT "chk_caso" CHECK ("CaSo" BETWEEN 1 AND 6);
ALTER TABLE "LichHen" ADD CONSTRAINT "chk_lichhen_thoigian" CHECK ("ThoiGianKetThuc" > "ThoiGianBatDau");

ALTER TABLE "CaLamViec" ADD CONSTRAINT "chk_calam_batdau_kethuc" CHECK ("BatDau" < "KetThuc");

ALTER TABLE "ChuKyTaiKham" ADD CONSTRAINT "chk_chuky_ngay" CHECK ("ChuKyNgay" > 0);
ALTER TABLE "ChuKyTaiKham" ADD CONSTRAINT "chk_chuky_trangthai" CHECK ("TrangThai" IN ('Đang hoạt động', 'Tạm dừng', 'Kết thúc'));

ALTER TABLE "Thuoc" ADD CONSTRAINT "chk_thuoc_dongia" CHECK ("DonGia" > 0);
ALTER TABLE "Thuoc" ADD CONSTRAINT "chk_thuoc_tonkho" CHECK ("SoLuongTon" >= 0);

ALTER TABLE "DonThuoc" ADD CONSTRAINT "chk_donthuoc_soluong" CHECK ("SoLuong" > 0);
ALTER TABLE "DonThuoc" ADD CONSTRAINT "chk_donthuoc_trangthai" CHECK ("TrangThai" IN ('Chờ phát thuốc', 'Đã phát thuốc', 'Chờ xử lý'));

ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tongtien" CHECK ("TongTien" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tienkham" CHECK ("TienKham" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_tienthuoc" CHECK ("TienThuoc" >= 0);
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_phuongthuc" CHECK ("PhuongThuc" IN ('Tiền mặt', 'Chuyển khoản QR', 'Thẻ POS'));
ALTER TABLE "HoaDon" ADD CONSTRAINT "chk_hoadon_trangthai" CHECK ("TrangThai" IN ('Chưa thanh toán', 'Đã thanh toán', 'Đã thanh toán tiền khám'));

ALTER TABLE "ChiTietDoanhThu" ADD CONSTRAINT "chk_doanhthu_giatri" CHECK ("DoanhThu" >= 0);
ALTER TABLE "ChiTietDoanhThu" ADD CONSTRAINT chk_loai_doanh_thu CHECK ("LoaiDoanhThu" IN ('Tiền khám', 'Tiền thuốc'));


CREATE INDEX "idx_benhnhan_sdt" ON "BenhNhan" ("SDT");
CREATE INDEX "idx_lichhen_timkiem" ON "LichHen" ("ThoiGianBatDau", "TrangThai");
CREATE INDEX "idx_benhan_theolich" ON "BenhAn" ("MaLH", "ThoiGianVao" DESC);
CREATE INDEX "idx_calamviec_bs_ngay" ON "CaLamViec" ("MaBS", "NgayLam");

ALTER TABLE "LichHen" ALTER COLUMN "TrangThai" SET DEFAULT 'Chờ khám';
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "ChuKyNgay" SET DEFAULT 30;
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "BatDau" SET DEFAULT CURRENT_DATE;
ALTER TABLE "ChuKyTaiKham" ALTER COLUMN "TrangThai" SET DEFAULT 'Đang hoạt động';
ALTER TABLE "BenhAn" ALTER COLUMN "ThoiGianVao" SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "BenhAn" ALTER COLUMN "NgayTao" SET DEFAULT CURRENT_DATE;
ALTER TABLE "Thuoc" ALTER COLUMN "DonVi" SET DEFAULT 'Viên';
ALTER TABLE "Thuoc" ALTER COLUMN "TenKho" SET DEFAULT 'Kho chính';
ALTER TABLE "HoaDon" ALTER COLUMN "NgayXuat" SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "HoaDon" ALTER COLUMN "PhuongThuc" SET DEFAULT 'Tiền mặt';
ALTER TABLE "HoaDon" ALTER COLUMN "TrangThai" SET DEFAULT 'Chưa thanh toán';
ALTER TABLE "HoaDon" ALTER COLUMN "TongTien" SET DEFAULT 0;
ALTER TABLE "HoaDon" ALTER COLUMN "TienKham" SET DEFAULT 0;
ALTER TABLE "HoaDon" ALTER COLUMN "TienThuoc" SET DEFAULT 0;
ALTER TABLE "ChiTietDoanhThu" ALTER COLUMN "NgayGhiNhan" SET DEFAULT CURRENT_DATE;
ALTER TABLE "DonThuoc" ALTER COLUMN "TrangThai" SET DEFAULT 'Chờ xử lý';

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE UNIQUE INDEX "idx_unique_bs_ngay_ca" ON "LichHen" ("MaBS", DATE("ThoiGianBatDau"), "CaSo");

