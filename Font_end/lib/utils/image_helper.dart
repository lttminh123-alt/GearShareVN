// lib/utils/image_helper.dart

/// Xử lý URL ảnh từ server, trả về placeholder nếu null/empty
String getImageUrl(dynamic imageUrl) {
  // Nếu null hoặc empty
  if (imageUrl == null || imageUrl.toString().isEmpty) {
    return 'https://via.placeholder.com/200?text=No+Image';
  }

  final url = imageUrl.toString().trim();

  // Nếu đã là full URL
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  // Nếu là relative path, thêm base URL
  return 'http://10.0.2.2:5000/$url';
}

/// Xử lý giá tiền, trả về "0" nếu null
String formatPrice(dynamic price) {
  if (price == null) return "0";
  try {
    final p = num.parse(price.toString());
    return p.toString();
  } catch (e) {
    return "0";
  }
}

/// Xử lý tên sản phẩm, trả về empty string nếu null
String getName(dynamic name) {
  if (name == null) return "Sản phẩm không có tên";
  return name.toString().isEmpty ? "Sản phẩm không có tên" : name.toString();
}
