SET search_path TO quanly_phongkham, public;

CREATE INDEX "idx_benhnhan_sdt" ON "BenhNhan" ("SDT");
CREATE INDEX "idx_lichhen_timkiem" ON "LichHen" ("ThoiGianBatDau", "TrangThai");
CREATE INDEX "idx_benhan_theolich" ON "BenhAn" ("MaLH", "ThoiGianVao" DESC);
CREATE INDEX "idx_calamviec_bs_ngay" ON "CaLamViec" ("MaBS", "NgayLam");