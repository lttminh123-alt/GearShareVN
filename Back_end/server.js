import express from "express";
import mongoose from "mongoose";
import cors from "cors";
import dotenv from "dotenv";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

// ==================== APP SETUP ====================
const app = express();
app.use(cors({ origin: "*", methods: ["GET", "POST", "PATCH", "PUT", "DELETE"] }));
app.use(express.json());

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ==================== DATABASE ====================
mongoose
  .connect(process.env.MONGO_URI || "mongodb://127.0.0.1:27017/mydb")
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.error("❌ MongoDB Error:", err));

// ==================== MODELS ====================
const userSchema = new mongoose.Schema({
  username: String,
  email: { type: String, unique: true },
  password: String,
  role: { type: String, default: "user" },
  phone_number: String,
  blocked: { type: Boolean, default: false },
}, { timestamps: true });
userSchema.index({ email: 1 }, { unique: true });
const User = mongoose.model("User", userSchema);

const productSchema = new mongoose.Schema(
  {
    name: String,
    price: Number,
    image: String,
    category: String,
    // Mảng lưu userId đã like sản phẩm
    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  },
  { timestamps: true }
);
const Product = mongoose.model("Product", productSchema);

// Collection CARTS - Giỏ hàng tạm thời
const cartSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    productId: { type: mongoose.Schema.Types.ObjectId, ref: "Product" },
    quantity: { type: Number, default: 1 },
    selectedOption: { type: Object, default: null },
    returnDate: { type: Date },
  },
  { timestamps: true }
);
const Cart = mongoose.model("Cart", cartSchema, "carts");

// ==================== CẬP NHẬT ORDER SCHEMA ====================
// Thay thế orderSchema cũ bằng schema này trong server.js

const orderSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    orderNumber: String,
    items: [
      {
        productId: { type: mongoose.Schema.Types.ObjectId, ref: "Product" },
        productName: String,
        productImage: String,
        basePrice: Number,
        quantity: Number,
        selectedOption: Object,
        returnDate: Date,
        // rental fields
        dailyRental: { type: Number, default: 0 },
        rentalDays: { type: Number, default: 0 },
        rentalExtra: { type: Number, default: 0 },
      },
    ],
    customerName: String,
    customerPhone: String,
    deliveryAddress: String,
    note: String,
    paymentMethod: String,
    totalAmount: Number,
    status: { type: String, default: "pending" }, // pending, confirmed, renting, returned, cancelled
    deliveryDate: { type: Date },
    calculatedReturnDate: { type: Date },
    // 👇 Thêm các trường mới để theo dõi hủy đơn
    cancelledBy: { 
      type: String, 
      enum: ["user", "admin"], 
      default: null 
    },
    cancellationReason: { 
      type: String, 
      default: "" 
    },
    cancelledAt: { 
      type: Date, 
      default: null 
    },
  },
  { timestamps: true }
);

const Order = mongoose.model("Order", orderSchema, "orders");

// ==================== AUTH ====================
function auth(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Chưa đăng nhập" });

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || "secret123");
    next();
  } catch (err) {
    return res.status(401).json({ message: "Token không hợp lệ" });
  }
}

// Helper để optional decode token (nếu có) — không bắt buộc
function tryDecodeToken(req) {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) return null;
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "secret123");
    return decoded;
  } catch {
    return null;
  }
}

// ==================== HELPERS ====================
function getDailyRentalRate(price) {
  const p = Number(price || 0);
  if (p <= 0) return 0;
  if (p <= 1_000_000) return +(p * 0.03);
  if (p <= 5_000_000) return +(p * 0.02);
  if (p <= 20_000_000) return +(p * 0.015);
  return +(p * 0.01);
}

function calcRentalDaysFromNow(returnDate) {
  if (!returnDate) return 0;
  const now = new Date();
  const r = new Date(returnDate);
  const msPerDay = 1000 * 60 * 60 * 24;
  const diff = r.getTime() - now.getTime();
  if (diff <= 0) return 0;
  return Math.max(1, Math.ceil(diff / msPerDay));
}

async function buildCartForUser(userId) {
  const carts = await Cart.find({ userId }).populate("productId").lean();

  let totalAmount = 0;
  const items = carts.map((c) => {
    const p = c.productId || {};
    const basePrice = (p.price != null) ? Number(p.price) : 0;
    const quantity = c.quantity ? Number(c.quantity) : 1;
    const extra = (c.selectedOption?.extraPrice) ? Number(c.selectedOption.extraPrice) : 0;

    const rentalDays = c.returnDate ? calcRentalDaysFromNow(c.returnDate) : 0;
    const dailyRental = getDailyRentalRate(basePrice);
    const rentalExtra = +(dailyRental * rentalDays); // per 1 unit
    const perUnitTotal = basePrice + extra + rentalExtra;
    const lineTotal = perUnitTotal * quantity;

    totalAmount += lineTotal;

    return {
      productId: p._id ? p : (c.productId || null),
      productName: p.name || "",
      productImage: p.image || "",
      basePrice,
      quantity,
      selectedOption: c.selectedOption || null,
      returnDate: c.returnDate,
      rentalDays,
      dailyRental,
      rentalExtra,
      perUnitTotal,
      lineTotal,
      _cartId: c._id,
    };
  });

  return {
    items,
    totalAmount,
    itemCount: items.length,
  };
}

// ==================== ROUTES ====================
app.get("/", (req, res) => res.json({ status: "API OK" }));

// ==================== REGISTER / LOGIN ====================
app.post("/api/users/register", async (req, res) => {
  try {
    const { username, email, password, phone_number } = req.body;
    if (!username || !email || !password)
      return res.status(400).json({ message: "Thiếu thông tin" });

    const exists = await User.findOne({ email });
    if (exists) return res.status(400).json({ message: "Email đã tồn tại" });

    const hashed = await bcrypt.hash(password, 10);
    const newUser = await User.create({ username, email, password: hashed, phone_number: phone_number || "" });

    res.status(201).json({ message: "Đăng ký thành công", user: newUser });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server" });
  }
});

app.post("/api/users/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Email không tồn tại" });

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(400).json({ message: "Sai mật khẩu" });

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET || "secret123", { expiresIn: "7d" });

    res.json({ message: "Đăng nhập thành công", token, user });
  } catch {
    res.status(500).json({ message: "Lỗi server" });
  }
});

// ==================== USER MANAGEMENT ====================
app.patch("/api/users/set-admin", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(404).json({ message: "User không tồn tại" });

    user.role = "admin";
    await user.save();
    res.json({ message: "Cập nhật role admin thành công" });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server" });
  }
});

app.get("/api/users", async (req, res) => {
  try {
    const users = await User.find().select("-password").sort({ createdAt: -1 }).lean();
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: "Lỗi server" });
  }
});

app.patch("/api/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const payload = req.body || {};

    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: "User không tồn tại" });

    if (user.role === "admin") {
      return res.status(403).json({ message: "Không thể chỉnh sửa ADMIN" });
    }

    if (payload.password) {
      payload.password = await bcrypt.hash(String(payload.password), 10);
    }

    const allowed = {};
    if (typeof payload.username === "string") allowed.username = payload.username;
    if (typeof payload.phone_number === "string") allowed.phone_number = payload.phone_number;
    if (typeof payload.password === "string") allowed.password = payload.password;
    if (typeof payload.blocked === "boolean") allowed.blocked = payload.blocked;

    Object.assign(user, allowed);
    await user.save();

    const result = user.toObject();
    delete result.password;
    res.json({ message: "Cập nhật thành công", user: result });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

app.delete("/api/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: "User không tồn tại" });

    if (user.role === "admin") {
      return res.status(403).json({ message: "Không thể xóa ADMIN" });
    }

    await User.findByIdAndDelete(id);
    res.json({ message: "Xóa user thành công" });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server" });
  }
});

// ==================== PRODUCT CRUD ====================
app.post("/api/products/add", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ message: "Chỉ admin được thêm sản phẩm!" });
    const { name, price, category, image } = req.body;
    const newProduct = await Product.create({ name, price: Number(price), category, image, likes: [] });
    res.json({ message: "Thêm sản phẩm thành công", product: newProduct });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server" });
  }
});

// Lấy tất cả products (giữ nguyên)
app.get("/api/products", async (req, res) => {
  const products = await Product.find().sort({ createdAt: -1 });
  res.json(products);
});

// Lấy 1 product (cập nhật để trả về cả thông tin likedByMe nếu token hợp lệ)
app.get("/api/products/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const product = await Product.findById(id).lean();
    if (!product) return res.status(404).json({ message: "Không tìm thấy sản phẩm" });

    // Thử decode token nếu có
    const decoded = tryDecodeToken(req);
    let likedByMe = false;
    if (decoded && decoded.id) {
      likedByMe = (product.likes || []).some((x) => String(x) === String(decoded.id));
    }

    res.json({ product, likedByMe });
  } catch (err) {
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// Cập nhật product (giữ nguyên)
app.put("/api/products/:id", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ message: "Không có quyền sửa" });
    const updated = await Product.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json({ message: "Cập nhật thành công", product: updated });
  } catch {
    res.status(500).json({ message: "Lỗi server" });
  }
});

// Xóa product
app.delete("/api/products/:id", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ message: "Không có quyền xóa" });
    await Product.findByIdAndDelete(req.params.id);
    res.json({ message: "Xóa sản phẩm thành công" });
  } catch {
    res.status(500).json({ message: "Lỗi server" });
  }
});

// ==================== LIKE / FAVORITE ROUTES ====================
/*
  PUT /api/products/:id/like
  - Yêu cầu auth
  - Nếu user đã like thì bỏ (unlike), nếu chưa thì push userId vào likes
  - Trả về { liked: boolean, product }
*/
app.put("/api/products/:id/like", auth, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const product = await Product.findById(id);
    if (!product) return res.status(404).json({ message: "Không tìm thấy sản phẩm" });

    const idx = (product.likes || []).findIndex((x) => String(x) === String(userId));
    let liked = false;
    if (idx === -1) {
      // chưa like -> add
      product.likes.push(userId);
      liked = true;
    } else {
      // đã like -> remove
      product.likes.splice(idx, 1);
      liked = false;
    }
    await product.save();

    res.json({ message: liked ? "Đã yêu thích" : "Bỏ yêu thích", liked, product });
  } catch (err) {
    console.error("PUT /api/products/:id/like error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== CART (CARTS COLLECTION) ====================
app.get("/api/cart", auth, async (req, res) => {
  try {
    const cart = await buildCartForUser(req.user.id);
    res.json(cart);
  } catch (err) {
    console.error("GET /api/cart error:", err);
    res.status(500).json({ message: "Lỗi server" });
  }
});

/*
  PUT /api/cart/update
  Body params:
   - productId (required)
   - optionName (optional)
   - quantity (optional) - number
   - returnDate (optional)
   - action (optional): "add" -> cộng dồn, "set" -> ghi đè (mặc định "set")
*/
app.put("/api/cart/update", auth, async (req, res) => {
  try {
    const { productId, optionName, quantity, returnDate, action } = req.body;
    if (!productId) return res.status(400).json({ message: "Thiếu productId" });

    const qtyNumber = typeof quantity === "number" ? Number(quantity) : (Number(quantity) || 0);
    const mode = (action === "add") ? "add" : "set"; // default set

    const selectedOptionFilter = optionName
      ? { "selectedOption.name": optionName }
      : { $or: [{ selectedOption: null }, { "selectedOption.name": { $exists: false } }] };

    const existingCart = await Cart.findOne({
      userId: req.user.id,
      productId,
      ...selectedOptionFilter,
    });

    if (existingCart) {
      if (mode === "add") {
        const addQty = qtyNumber > 0 ? qtyNumber : 1;
        existingCart.quantity = Number(existingCart.quantity || 0) + addQty;
      } else {
        if (qtyNumber > 0) existingCart.quantity = qtyNumber;
      }

      if (optionName && (!existingCart.selectedOption || existingCart.selectedOption.name !== optionName)) {
        existingCart.selectedOption = { name: optionName, extraPrice: 0 };
      }
      if (returnDate) {
        existingCart.returnDate = new Date(returnDate);
      }

      if (existingCart.quantity <= 0) {
        await Cart.findByIdAndDelete(existingCart._id);
      } else {
        await existingCart.save();
      }
    } else {
      const createQty = (mode === "add") ? (qtyNumber > 0 ? qtyNumber : 1) : (qtyNumber > 0 ? qtyNumber : 1);
      const cartData = {
        userId: req.user.id,
        productId,
        quantity: createQty,
        selectedOption: optionName ? { name: optionName, extraPrice: 0 } : null,
      };
      if (returnDate) {
        cartData.returnDate = new Date(returnDate);
      }
      await Cart.create(cartData);
    }

    const cart = await buildCartForUser(req.user.id);
    res.json({ message: "Cập nhật cart thành công", cart });
  } catch (err) {
    console.error("PUT /api/cart/update error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

app.delete("/api/cart/remove", auth, async (req, res) => {
  try {
    const { productId, optionName } = req.body;
    if (!productId) return res.status(400).json({ message: "Thiếu productId" });

    const selectedOptionFilter = optionName
      ? { "selectedOption.name": optionName }
      : { $or: [{ selectedOption: null }, { "selectedOption.name": { $exists: false } }] };

    await Cart.findOneAndDelete({
      userId: req.user.id,
      productId,
      ...selectedOptionFilter,
    });

    const cart = await buildCartForUser(req.user.id);
    res.json({ message: "Xóa sản phẩm khỏi cart thành công", cart });
  } catch (err) {
    console.error("DELETE /api/cart/remove error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

app.delete("/api/cart/clear", auth, async (req, res) => {
  try {
    await Cart.deleteMany({ userId: req.user.id });
    const cart = await buildCartForUser(req.user.id);
    res.json({ message: "Đã xóa toàn bộ giỏ hàng", cart });
  } catch (err) {
    console.error("DELETE /api/cart/clear error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== ORDERS CREATE ====================
app.post("/api/orders/create", auth, async (req, res) => {
  try {
    const { customerName, customerPhone, deliveryAddress, note, paymentMethod } = req.body;

    const cartItems = await Cart.find({ userId: req.user.id }).populate("productId").lean();

    if (!cartItems || cartItems.length === 0) {
      return res.status(400).json({ message: "Giỏ hàng trống" });
    }

    const orderNumber = `ORD-${Date.now()}-${Math.floor(Math.random() * 9000 + 1000)}`;

    let computedTotal = 0;
    const items = cartItems.map((c) => {
      const p = c.productId || {};
      const basePrice = (p.price != null) ? Number(p.price) : 0;
      const quantity = c.quantity ? Number(c.quantity) : 1;
      const extra = (c.selectedOption?.extraPrice) ? Number(c.selectedOption.extraPrice) : 0;

      const rentalDays = c.returnDate ? calcRentalDaysFromNow(c.returnDate) : 0;
      const dailyRental = getDailyRentalRate(basePrice);
      const rentalExtra = +(dailyRental * rentalDays);

      const perUnitTotal = basePrice + extra + rentalExtra;
      const lineTotal = perUnitTotal * quantity;

      computedTotal += lineTotal;

      return {
        productId: p._id || null,
        productName: p.name || "",
        productImage: p.image || "",
        basePrice,
        quantity,
        selectedOption: c.selectedOption || null,
        returnDate: c.returnDate || null,
        dailyRental,
        rentalDays,
        rentalExtra,
      };
    });

    const order = await Order.create({
      userId: req.user.id,
      orderNumber,
      items,
      customerName,
      customerPhone,
      deliveryAddress,
      note,
      paymentMethod,
      totalAmount: Number(computedTotal) || 0,
      status: "pending",
    });

    await Cart.deleteMany({ userId: req.user.id });

    const cart = await buildCartForUser(req.user.id);
    res.status(201).json({
      message: "Đặt hàng thành công, đơn hàng đang chờ xác nhận",
      order: {
        orderNumber: order.orderNumber,
        id: order._id,
      },
      cart,
    });
  } catch (err) {
    console.error("POST /api/orders/create error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== ADMIN: XÁC NHẬN ĐƠN HÀNG ====================
app.put("/api/orders/:orderId/confirm", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res.status(403).json({ message: "Chỉ admin mới có quyền xác nhận đơn hàng" });
    }

    const { orderId } = req.params;
    const { deliveryDays } = req.body;

    if (!deliveryDays || deliveryDays <= 0) {
      return res.status(400).json({ message: "Vui lòng nhập số ngày giao hàng hợp lệ" });
    }

    const order = await Order.findById(orderId);
    if (!order) {
      return res.status(404).json({ message: "Không tìm thấy đơn hàng" });
    }

    if (order.status !== "pending") {
      return res.status(400).json({ message: "Đơn hàng đã được xử lý" });
    }

    const deliveryDate = new Date();
    deliveryDate.setDate(deliveryDate.getDate() + Number(deliveryDays));

    order.status = "confirmed";
    order.deliveryDate = deliveryDate;

    for (const item of order.items) {
      if (item.returnDate) {
        const rentalDays = Math.ceil((new Date(item.returnDate) - new Date()) / (1000 * 60 * 60 * 24));
        const calculatedReturnDate = new Date(deliveryDate);
        calculatedReturnDate.setDate(calculatedReturnDate.getDate() + rentalDays);
        order.calculatedReturnDate = calculatedReturnDate;
      }
    }

    await order.save();

    res.json({
      message: "Xác nhận đơn hàng thành công",
      deliveryDate,
      orderNumber: order.orderNumber,
    });
  } catch (err) {
    console.error("PUT /api/orders/:orderId/confirm error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== CANCEL ORDER (NEW) ====================
app.put("/api/orders/:orderId/cancel", auth, async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await Order.findById(orderId);
    if (!order) {
      return res.status(404).json({ message: "Không tìm thấy đơn hàng" });
    }

    if (order.status === "returned" || order.status === "cancelled") {
      return res.status(400).json({ message: "Đơn hàng không thể hủy (đã trả hoặc đã hủy)" });
    }

    if (req.user.role !== "admin") {
      if (!order.userId || order.userId.toString() !== req.user.id) {
        return res.status(403).json({ message: "Bạn không có quyền hủy đơn này" });
      }
      if (order.status !== "pending") {
        return res.status(400).json({ message: "Chỉ đơn 'pending' mới có thể bị hủy bởi khách hàng" });
      }
    }

    order.status = "cancelled";
    await order.save();

    res.json({ message: "Hủy đơn hàng thành công", orderNumber: order.orderNumber });
  } catch (err) {
    console.error("PUT /api/orders/:orderId/cancel error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== ADMIN: LẤY TẤT CẢ ĐƠN HÀNG ====================
app.get("/api/orders/all", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res.status(403).json({ message: "Chỉ admin mới có quyền xem tất cả đơn hàng" });
    }

    const orders = await Order.find()
      .populate("userId", "username email phone_number")
      .sort({ createdAt: -1 })
      .lean();

    res.json(orders);
  } catch (err) {
    console.error("GET /api/orders/all error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== FAVORITES API (NEW) ====================

// Lấy danh sách sản phẩm yêu thích
app.get("/api/favorites", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    // Lấy tất cả sản phẩm có userId nằm trong mảng likes
    const favorites = await Product.find({ likes: userId }).lean();

    res.json(favorites);
  } catch (err) {
    console.error("GET /api/favorites error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// Toggle yêu thích
app.post("/api/favorites/toggle", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { productId } = req.body;

    if (!productId) {
      return res.status(400).json({ message: "Thiếu productId" });
    }

    const product = await Product.findById(productId);
    if (!product) {
      return res.status(404).json({ message: "Không tìm thấy sản phẩm" });
    }

    const index = product.likes.findIndex(
      (uid) => String(uid) === String(userId)
    );

    let liked = false;

    if (index === -1) {
      product.likes.push(userId);
      liked = true;
    } else {
      product.likes.splice(index, 1);
      liked = false;
    }

    await product.save();

    res.json({
      message: liked ? "Đã thêm vào yêu thích" : "Đã bỏ yêu thích",
      liked,
    });
  } catch (err) {
    console.error("POST /api/favorites/toggle error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== THÊM VÀO file server.js (Express) ====================

// API: Lấy đơn hàng của user hiện tại
app.get("/api/orders/my-orders", auth, async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .lean();

    res.json({ orders });
  } catch (err) {
    console.error("GET /api/orders/my-orders error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// API: User xác nhận đã nhận được hàng (pending -> confirmed -> renting)
app.put("/api/orders/:orderId/received", auth, async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await Order.findById(orderId);

    if (!order) {
      return res.status(404).json({ message: "Không tìm thấy đơn hàng" });
    }

    // Chỉ user sở hữu đơn hàng mới có thể xác nhận nhận
    if (order.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Bạn không có quyền thực hiện hành động này" });
    }

    // Chỉ đơn "confirmed" mới có thể chuyển sang "renting"
    if (order.status !== "confirmed") {
      return res.status(400).json({ message: "Đơn hàng phải ở trạng thái 'confirmed' để nhận hàng" });
    }

    order.status = "renting";
    await order.save();

    res.json({ message: "Đã xác nhận nhận hàng", order });
  } catch (err) {
    console.error("PUT /api/orders/:orderId/received error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// API: User xác nhận trả hàng (renting -> returned)
app.put("/api/orders/:orderId/returned", auth, async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await Order.findById(orderId);

    if (!order) {
      return res.status(404).json({ message: "Không tìm thấy đơn hàng" });
    }

    // Chỉ user sở hữu đơn hàng mới có thể xác nhận trả
    if (order.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: "Bạn không có quyền thực hiện hành động này" });
    }

    // Chỉ đơn "renting" mới có thể chuyển sang "returned"
    if (order.status !== "renting") {
      return res.status(400).json({ message: "Đơn hàng phải ở trạng thái 'renting' để trả hàng" });
    }

    order.status = "returned";
    await order.save();

    res.json({ message: "Đã xác nhận trả hàng", order });
  } catch (err) {
    console.error("PUT /api/orders/:orderId/returned error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// Cập nhật schema Order để lưu thông tin hủy đơn
// Thêm vào orderSchema:
/*
cancelledBy: { type: String, enum: ["user", "admin"], default: null },
cancellationReason: { type: String, default: "" },
cancelledAt: { type: Date, default: null },
*/

// Cập nhật endpoint hủy đơn hàng hiện tại
app.put("/api/orders/:orderId/cancel", auth, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { reason } = req.body;
    const order = await Order.findById(orderId);

    if (!order) {
      return res.status(404).json({ message: "Không tìm thấy đơn hàng" });
    }

    if (order.status === "returned" || order.status === "cancelled") {
      return res.status(400).json({ message: "Đơn hàng không thể hủy (đã trả hoặc đã hủy)" });
    }

    if (req.user.role !== "admin") {
      if (!order.userId || order.userId.toString() !== req.user.id) {
        return res.status(403).json({ message: "Bạn không có quyền hủy đơn này" });
      }
      if (order.status !== "pending") {
        return res.status(400).json({ message: "Chỉ đơn 'pending' mới có thể bị hủy bởi khách hàng" });
      }
    }

    order.status = "cancelled";
    order.cancelledBy = req.user.role === "admin" ? "admin" : "user";
    order.cancellationReason = reason || "Khách hàng hủy đơn";
    order.cancelledAt = new Date();

    await order.save();

    res.json({ 
      message: "Hủy đơn hàng thành công", 
      orderNumber: order.orderNumber,
      cancelledBy: order.cancelledBy,
    });
  } catch (err) {
    console.error("PUT /api/orders/:orderId/cancel error:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
});

// ==================== RUN SERVER ====================
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🔥 Server chạy tại http://localhost:${PORT}`));
