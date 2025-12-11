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
const usersCol = db.collection("users");

// ========== LOGIN ==========
app.post("/login", async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: "Email dan password wajib diisi" });
      return;
    }

    const snap = await usersCol.where("email", "==", email).limit(1).get();

    if (snap.empty) {
      res.status(401).json({ error: "Email atau password salah" });
      return;
    }

    const doc = snap.docs[0];
    const data = doc.data() as {
      name?: string;
      email?: string;
      password?: string;
      role?: string;
    };

    if (data.password !== password) {
      res.status(401).json({ error: "Email atau password salah" });
      return;
    }

    res.json({
      success: true,
      user: {
        id: doc.id,
        name: data.name ?? "",
        email: data.email ?? "",
        role: data.role ?? "cashier",
      },
    });
  } catch (err: any) {
    console.error("POST /login error:", err);
    res.status(500).json({
      error: "Login gagal",
      details: err?.message ?? String(err),
    });
  }
});

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
    const lowStockItems: any[] = [];

    await db.runTransaction(async (tx) => {
      const itemEntries = items.map((entry) => ({
        itemId: entry.itemId,
        quantity: entry.quantity,
        ref: itemsCol.doc(entry.itemId),
      }));

      const snapshots = await Promise.all(
        itemEntries.map((e) => tx.get(e.ref))
      );

      const saleItems: any[] = [];
      let grandTotal = 0;
      let grandProfit = 0;

      snapshots.forEach((snap, index) => {
        const { itemId, quantity, ref } = itemEntries[index];

        if (!snap.exists) {
          throw new Error(`Item dengan id ${itemId} tidak ditemukan`);
        }

        const itemData: any = snap.data();
        const currentStock = Number(itemData.stock ?? 0);
        const unitPrice = Number(itemData.sellingPrice ?? 0);
        const purchasePrice = Number(itemData.purchasePrice ?? 0);
        const minStock = Number(itemData.minStock ?? 0);

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
        const profit = (unitPrice - purchasePrice) * quantity;

        tx.update(ref, {
          stock: newStock,
          updatedAt: now,
        });

        saleItems.push({
          itemId,
          itemName: itemData.name ?? "",
          quantity,
          unitPrice,
          purchasePrice,
          totalPrice,
          profit,
        });

        if (newStock <= minStock) {
          lowStockItems.push({
            itemId,
            itemName: itemData.name ?? "",
            currentStock: newStock,
            minStock,
          });
        }

        grandTotal += totalPrice;
        grandProfit += profit;
      });

      const saleRef = salesCol.doc();
      tx.set(saleRef, {
        items: saleItems,
        totalPrice: grandTotal,
        totalProfit: grandProfit,
        createdAt: now,
      });
    });

    res.status(201).json({
      success: true,
      lowStockItems,
    });
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

// ============== REPORTS SUMMARY =============
app.get("/reports/summary", async (_req: Request, res: Response): Promise<void> => {
  try {
    const snap = await salesCol.get();

    let totalRevenue = 0;
    let totalProfit = 0;

    const perDay = new Map<string, { revenue: number; profit: number }>();

    snap.forEach((doc) => {
      const data = doc.data() as any;

      const revenue = Number(data.totalPrice ?? 0);
      const profit = Number(data.totalProfit ?? 0);

      totalRevenue += revenue;
      totalProfit += profit;

      // Normalize createdAt
      let createdAt: Date;
      const raw = data.createdAt;
      if (raw && typeof raw.toDate === "function") createdAt = raw.toDate();
      else createdAt = new Date(raw);

      const key = createdAt.toISOString().slice(0, 10); // yyyy-mm-dd

      const prev = perDay.get(key) ?? { revenue: 0, profit: 0 };
      prev.revenue += revenue;
      prev.profit += profit;
      perDay.set(key, prev);
    });

    const series = Array.from(perDay.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, v]) => ({
        date,
        revenue: v.revenue,
        profit: v.profit,
      }));

    res.json({
      success: true,
      totalRevenue,
      totalProfit,
      series,
    });
  } catch (err: any) {
    res.status(500).json({
      error: "Gagal mengambil laporan",
      details: err?.message,
    });
  }
});

// Export 1 fungsi HTTPS v2
export const api = onRequest((req, res) => app(req, res));