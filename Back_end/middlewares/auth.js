import jwt from "jsonwebtoken";

// Middleware xác thực token
const authMiddleware = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Thiếu token hoặc token không hợp lệ" });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "secret_key");

    req.user = decoded; // gắn user.id và role từ token vào request
    next();
  } catch (error) {
    console.error("❌ Lỗi xác thực:", error.message);
    res.status(403).json({ message: "Token không hợp lệ hoặc đã hết hạn" });
  }
};

export default authMiddleware;
