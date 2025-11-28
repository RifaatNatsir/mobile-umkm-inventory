import * as admin from "firebase-admin";
import express, { Request, Response } from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";

setGlobalOptions({ region: "asia-southeast2" });

admin.initializeApp();
const db = admin.firestore();

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

// ============== HEALTH CHECK =================
app.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "ok",
    message: "UMKM Inventory API is running",
    time: new Date().toISOString(),
  });
});

// ============== ITEMS COLLECTION =============
const itemsCol = db.collection("items");
const salesCol = db.collection("sales");

// GET /items  -> list barang
app.get("/items", async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await itemsCol.get();
    const items = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ data: items });
    return;
  } catch (err: any) {
    console.error("GET /items error:", err);
    res.status(500).json({
      error: "Failed to get items",
      details: err?.message ?? String(err),
    });
    return;
  }
});

// GET /sales  -> daftar transaksi penjualan
app.get("/sales", async (_req: Request, res: Response): Promise<void> => {
  try {
    const snapshot = await salesCol
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    const sales = snapshot.docs.map((doc) => {
      const data: any = doc.data();
      let createdAtStr = "";

      if (data.createdAt && typeof data.createdAt.toDate === "function") {
        createdAtStr = data.createdAt.toDate().toISOString();
      } else if (typeof data.createdAt === "string") {
        createdAtStr = data.createdAt;
      }

      return {
        id: doc.id,
        totalPrice: data.totalPrice ?? 0,
        createdAt: createdAtStr,
        items: data.items ?? [],
      };
    });

    res.json({ data: sales });
  } catch (err: any) {
    console.error("GET /sales error:", err);
    res.status(500).json({
      error: "Failed to get sales",
      details: err?.message ?? String(err),
    });
  }
});

// POST /sales  -> catat penjualan & update stok
app.post("/sales", async (req: Request, res: Response): Promise<void> => {
  try {
    const items = req.body.items as Array<{ itemId: string; quantity: number }>;

    if (!Array.isArray(items) || items.length === 0) {
      res.status(400).json({
        error: "Field 'items' harus berupa array dan tidak boleh kosong",
      });
      return;
    }

    const now = new Date();

    await db.runTransaction(async (tx) => {
      // 1) Siapkan ref untuk semua item
      const itemEntries = items.map((entry) => ({
        itemId: entry.itemId,
        quantity: entry.quantity,
        ref: itemsCol.doc(entry.itemId),
      }));

      // 2) BACA SEMUA ITEM DULU (SEMUA READ)
      const snapshots = await Promise.all(
        itemEntries.map((e) => tx.get(e.ref))
      );

      const saleItems: any[] = [];
      let grandTotal = 0;

      // 3) BARU PROSES & TULIS (WRITE) SETELAH SEMUA READ SELESAI
      snapshots.forEach((snap, index) => {
        const { itemId, quantity, ref } = itemEntries[index];

        if (!snap.exists) {
          throw new Error(`Item dengan id ${itemId} tidak ditemukan`);
        }

        const itemData: any = snap.data();
        const currentStock = Number(itemData.stock ?? 0);
        const unitPrice = Number(itemData.sellingPrice ?? 0);

        if (!quantity || quantity <= 0) {
          throw new Error("ItemId dan quantity (>0) wajib diisi");
        }

        if (currentStock < quantity) {
          throw new Error(
            `Stok tidak cukup untuk ${itemData.name ?? "barang"}`
          );
        }

        const newStock = currentStock - quantity;
        const totalPrice = unitPrice * quantity;

        // UPDATE STOK (WRITE)
        tx.update(ref, {
          stock: newStock,
          updatedAt: now,
        });

        saleItems.push({
          itemId,
          itemName: itemData.name ?? "",
          quantity,
          unitPrice,
          totalPrice,
        });

        grandTotal += totalPrice;
      });

      // 4) SIMPAN DOKUMEN TRANSAKSI (WRITE)
      const saleRef = salesCol.doc();
      tx.set(saleRef, {
        items: saleItems,
        totalPrice: grandTotal,
        createdAt: now,
      });
    });

    res.status(201).json({ success: true });
  } catch (err: any) {
    console.error("POST /sales error:", err);
    const msg = err?.message ?? String(err);
    const status =
      msg.includes("Stok tidak cukup") || msg.includes("tidak ditemukan")
        ? 400
        : 500;

    res.status(status).json({
      error: "Failed to create sale",
      details: msg,
    });
  }
});

// POST /items  -> tambah barang
app.post(
  "/items",
  async (req: Request, res: Response): Promise<void> => {
    try {
      const {
        name,
        sku,
        category,
        purchasePrice,
        sellingPrice,
        stock,
        minStock,
        unit,
      } = req.body;

      if (!name || !sku) {
        res.status(400).json({ error: "name dan sku wajib diisi" });
        return;
      }

      const now = new Date();

      const docRef = await itemsCol.add({
        name,
        sku,
        category: category ?? "",
        purchasePrice: purchasePrice ?? 0,
        sellingPrice: sellingPrice ?? 0,
        stock: stock ?? 0,
        minStock: minStock ?? 0,
        unit: unit ?? "pcs",
        createdAt: now,
        updatedAt: now,
      });

      const newDoc = await docRef.get();
      res.status(201).json({ id: newDoc.id, ...newDoc.data() });
      return;
    } catch (err: any) {
      console.error("POST /items error:", err);
      res.status(500).json({
        error: "Failed to create item",
        details: err?.message ?? String(err),
      });
      return;
    }
  }
);

// PUT /items/:id  -> update barang
app.put(
  "/items/:id",
  async (req: Request, res: Response): Promise<void> => {
    try {
      const id = req.params.id;
      const now = new Date();

      const data = {
        ...req.body,
        updatedAt: now,
      };

      await itemsCol.doc(id).update(data);
      const updated = await itemsCol.doc(id).get();
      res.json({ id: updated.id, ...updated.data() });
      return;
    } catch (err: any) {
      console.error("PUT /items error:", err);
      res.status(500).json({
        error: "Failed to update item",
        details: err?.message ?? String(err),
      });
      return;
    }
  }
);

// DELETE /items/:id  -> hapus barang
app.delete(
  "/items/:id",
  async (req: Request, res: Response): Promise<void> => {
    try {
      const id = req.params.id;
      await itemsCol.doc(id).delete();
      res.json({ success: true });
      return;
    } catch (err: any) {
      console.error("DELETE /items error:", err);
      res.status(500).json({
        error: "Failed to delete item",
        details: err?.message ?? String(err),
      });
      return;
    }
  }
);

// Export 1 fungsi HTTPS v2
export const api = onRequest((req, res) => app(req, res));