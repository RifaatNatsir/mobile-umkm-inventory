import * as admin from "firebase-admin";
import express, { Request, Response } from "express";
import cors from "cors";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";

setGlobalOptions({ region: "asia-southeast2" });

admin.initializeApp();
const db = admin.firestore();

const app = express();

// middlewares
app.use(cors({ origin: true }));
app.use(express.json());

// =========================
// ROUTES
// =========================

// Cek API hidup
app.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "ok",
    message: "UMKM Inventory API is running",
    time: new Date().toISOString(),
  });
});

// Koleksi Firestore
const itemsCol = db.collection("items");

// GET /items -> ambil semua barang
app.get("/items", async (_req: Request, res: Response) => {
  try {
    const snapshot = await itemsCol.get();
    const items = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ data: items });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to get items" });
  }
});

// POST /items -> tambah barang baru
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

      const docRef = await itemsCol.add({
        name,
        sku,
        category: category || "",
        purchasePrice: purchasePrice || 0,
        sellingPrice: sellingPrice || 0,
        stock: stock || 0,
        minStock: minStock || 0,
        unit: unit || "pcs",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const newDoc = await docRef.get();
      res.status(201).json({ id: newDoc.id, ...newDoc.data() });
      return;
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to create item" });
      return;
    }
  }
);

// PUT /items/:id -> update barang
app.put("/items/:id", async (req: Request, res: Response) => {
  try {
    const id = req.params.id;
    const data = {
      ...req.body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await itemsCol.doc(id).update(data);
    const updated = await itemsCol.doc(id).get();
    res.json({ id: updated.id, ...updated.data() });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update item" });
  }
});

// DELETE /items/:id -> hapus barang
app.delete("/items/:id", async (req: Request, res: Response) => {
  try {
    const id = req.params.id;
    await itemsCol.doc(id).delete();
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete item" });
  }
});

// Export sebagai HTTPS Function v2
export const api = onRequest((req, res) => app(req, res));