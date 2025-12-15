import User from "../models/user.model.js";
import Product from "../models/product.model.js";

// Toggle yêu thích
export const toggleFavorite = async (req, res) => {
  try {
    // ✅ Thử cả .id và ._id để tương thích
    const userId = req.user.id || req.user._id;
    const { productId } = req.body;

    if (!userId) {
      return res.status(401).json({ message: "Không xác thực được user" });
    }

    if (!productId) {
      return res.status(400).json({ message: "Thiếu productId" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User không tồn tại" });
    }

    const index = user.favorites.indexOf(productId);
    if (index >= 0) {
      // Xóa khỏi yêu thích
      user.favorites.splice(index, 1);
      console.log(`✅ Đã xóa product ${productId} khỏi favorites của user ${userId}`);
    } else {
      // Thêm vào yêu thích
      user.favorites.push(productId);
      console.log(`✅ Đã thêm product ${productId} vào favorites của user ${userId}`);
    }

    await user.save();
    res.status(200).json({ 
      message: index >= 0 ? "Đã xóa khỏi yêu thích" : "Đã thêm vào yêu thích",
      favorites: user.favorites,
      action: index >= 0 ? "removed" : "added"
    });
  } catch (err) {
    console.error("❌ Lỗi toggle favorite:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
};

// Lấy danh sách yêu thích
export const getFavorites = async (req, res) => {
  try {
    // ✅ Thử cả .id và ._id
    const userId = req.user.id || req.user._id;

    if (!userId) {
      return res.status(401).json({ message: "Không xác thực được user" });
    }

    const user = await User.findById(userId).populate("favorites");

    if (!user) {
      return res.status(404).json({ message: "User không tồn tại" });
    }

    console.log(`✅ User ${userId} có ${user.favorites?.length || 0} sản phẩm yêu thích`);

    // Trả về array sản phẩm trực tiếp
    res.status(200).json(user.favorites || []);
  } catch (err) {
    console.error("❌ Lỗi get favorites:", err);
    res.status(500).json({ message: "Lỗi server", error: err.message });
  }
};