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