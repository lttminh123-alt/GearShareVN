import Cart from "../models/cart.model.js";
import Product from "../models/product.model.js";

// ✅ Thêm sản phẩm vào Đơn hàng
export const addToCart = async (req, res) => {
  try {
    const userId = req.user.id;
    const { productId, quantity, selectedOption } = req.body;

    // Kiểm tra dữ liệu đầu vào
    if (!productId || !quantity || quantity < 1) {
      return res.status(400).json({
        message: "Thiếu thông tin sản phẩm hoặc số lượng không hợp lệ",
      });
    }

    // Kiểm tra sản phẩm có tồn tại không
    const product = await Product.findById(productId);
    if (!product) {
      return res.status(404).json({ message: "Sản phẩm không tồn tại" });
    }

    // Tính giá
    const extraPrice = selectedOption?.extraPrice || 0;
    const unitPrice = product.price + extraPrice;
    const totalPrice = unitPrice * quantity;

    // Tìm Đơn hàng của user
    let cart = await Cart.findOne({ userId });
    if (!cart) {
      cart = new Cart({
        userId,
        items: [],
        totalAmount: 0,
        itemCount: 0,
      });
    }

    // ✅ Kiểm tra trùng hoàn toàn sản phẩm (id + option)
    const existingItemIndex = cart.items.findIndex((item) => {
      const sameProductId = item.productId.toString() === productId;

      // Nếu cả hai không có option
      if (!item.selectedOption?.name && !selectedOption?.name) {
        return sameProductId;
      }

      // Nếu có option thì phải trùng cả tên lẫn giá cộng thêm
      const sameOption =
        item.selectedOption?.name === selectedOption?.name &&
        item.selectedOption?.extraPrice === selectedOption?.extraPrice;

      return sameProductId && sameOption;
    });

    if (existingItemIndex > -1) {
      // 🔹 Nếu trùng sản phẩm + option → cộng dồn số lượng
      cart.items[existingItemIndex].quantity += quantity;
      cart.items[existingItemIndex].totalPrice =
        cart.items[existingItemIndex].unitPrice *
        cart.items[existingItemIndex].quantity;
    } else {
      // 🔹 Nếu khác option hoặc chưa có → thêm mới
      cart.items.push({
        productId: product._id,
        productName: product.name,
        productImage: product.image,
        basePrice: product.price,
        selectedOption: {
          name: selectedOption?.name || "",
          extraPrice: extraPrice,
        },
        quantity,
        unitPrice,
        totalPrice,
      });
    }

    // Cập nhật tổng tiền và số lượng
    cart.totalAmount = cart.items.reduce((sum, i) => sum + i.totalPrice, 0);
    cart.itemCount = cart.items.reduce((sum, i) => sum + i.quantity, 0);

    await cart.save();

    res.status(200).json({
      message: "Đã thêm sản phẩm vào Đơn hàng",
      cart,
    });
  } catch (err) {
    console.error("❌ Lỗi khi thêm vào Đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi thêm vào Đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Lấy Đơn hàng - FIXED: Không dùng populate, trả về đúng format
export const getCart = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // ❌ Không dùng populate vì nó thay đổi cấu trúc dữ liệu
    const cart = await Cart.findOne({ userId });

    if (!cart) {
      return res.status(200).json({
        items: [],
        totalAmount: 0,
        itemCount: 0,
      });
    }

    // ✅ Trả về đúng format mà Flutter mong đợi
    const response = {
      _id: cart._id,
      userId: cart.userId,
      items: cart.items.map(item => ({
        productId: item.productId.toString(), // Chuyển ObjectId thành string
        productName: item.productName,
        productImage: item.productImage,
        basePrice: item.basePrice,
        selectedOption: {
          name: item.selectedOption?.name || "",
          extraPrice: item.selectedOption?.extraPrice || 0
        },
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice
      })),
      totalAmount: cart.totalAmount,
      itemCount: cart.itemCount,
      createdAt: cart.createdAt,
      updatedAt: cart.updatedAt
    };

    console.log("✅ Trả về Đơn hàng:", response);
    res.status(200).json(response);
    
  } catch (err) {
    console.error("❌ Lỗi khi lấy Đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi lấy Đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Cập nhật số lượng
export const updateCartItem = async (req, res) => {
  try {
    const userId = req.user.id;
    const { productId, optionName, quantity } = req.body;

    const cart = await Cart.findOne({ userId });
    if (!cart) {
      return res.status(404).json({ message: "Không tìm thấy Đơn hàng" });
    }

    const itemIndex = cart.items.findIndex(
      (item) =>
        item.productId.toString() === productId &&
        (item.selectedOption?.name || "") === (optionName || "")
    );

    if (itemIndex === -1) {
      return res.status(404).json({ message: "Không tìm thấy sản phẩm trong giỏ" });
    }

    if (quantity === 0) {
      cart.items.splice(itemIndex, 1);
    } else {
      cart.items[itemIndex].quantity = quantity;
      cart.items[itemIndex].totalPrice =
        cart.items[itemIndex].unitPrice * quantity;
    }

    cart.totalAmount = cart.items.reduce((sum, i) => sum + i.totalPrice, 0);
    cart.itemCount = cart.items.reduce((sum, i) => sum + i.quantity, 0);

    await cart.save();

    res.status(200).json({ message: "Đã cập nhật Đơn hàng", cart });
  } catch (err) {
    console.error("❌ Lỗi khi cập nhật Đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi cập nhật Đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Xóa sản phẩm khỏi giỏ
export const removeFromCart = async (req, res) => {
  try {
    const userId = req.user.id;
    const { productId, optionName } = req.body;

    const cart = await Cart.findOne({ userId });
    if (!cart) {
      return res.status(404).json({ message: "Không tìm thấy Đơn hàng" });
    }

    const itemsBefore = cart.items.length;

    cart.items = cart.items.filter(
      (item) =>
        !(
          item.productId.toString() === productId &&
          (item.selectedOption?.name || "") === (optionName || "")
        )
    );

    const itemsAfter = cart.items.length;

    if (itemsBefore === itemsAfter) {
      return res.status(404).json({ message: "Không tìm thấy sản phẩm để xóa" });
    }

    cart.totalAmount = cart.items.reduce((sum, i) => sum + i.totalPrice, 0);
    cart.itemCount = cart.items.reduce((sum, i) => sum + i.quantity, 0);

    await cart.save();

    res.status(200).json({ message: "Đã xóa sản phẩm khỏi Đơn hàng", cart });
  } catch (err) {
    console.error("❌ Lỗi khi xóa khỏi Đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi xóa khỏi Đơn hàng",
      error: err.message,
    });
  }
};

// ✅ Xóa toàn bộ giỏ
export const clearCart = async (req, res) => {
  try {
    const userId = req.user.id;

    const cart = await Cart.findOne({ userId });
    if (!cart) {
      return res.status(404).json({ message: "Không tìm thấy Đơn hàng" });
    }

    cart.items = [];
    cart.totalAmount = 0;
    cart.itemCount = 0;

    await cart.save();

    res.status(200).json({ message: "Đã xóa toàn bộ Đơn hàng", cart });
  } catch (err) {
    console.error("❌ Lỗi khi xóa Đơn hàng:", err);
    res.status(500).json({
      message: "Lỗi khi xóa Đơn hàng",
      error: err.message,
    });
  }
};