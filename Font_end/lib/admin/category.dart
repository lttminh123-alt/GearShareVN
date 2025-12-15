import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class Option {
  final String name;
  final int extraPrice;

  Option({required this.name, this.extraPrice = 0});

  Map<String, dynamic> toJson() => {"name": name, "extraPrice": extraPrice};

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      name: json["name"] ?? "",
      extraPrice: (json["extraPrice"] is int)
          ? json["extraPrice"]
          : int.tryParse(json["extraPrice"].toString()) ?? 0,
    );
  }
}

class Drink {
  final String? id;
  final String localId;
  final String name;
  final String image;
  final int price;
  final double rating;
  final String category;
  final String description;
  final List<Option> options;

  Drink({
    this.id,
    String? localId,
    required this.name,
    required this.image,
    required this.price,
    required this.rating,
    required this.category,
    required this.description,
    this.options = const [],
  }) : localId = localId ?? _generateTempId();

  Map<String, dynamic> toJson() => {
    if (id != null && id!.length == 24) "_id": id,
    "name": name,
    "image": image,
    "price": price,
    "rating": rating,
    "category": category,
    "description": description,
    "options": options.map((o) => o.toJson()).toList(),
  };

  factory Drink.fromJson(Map<String, dynamic> json) {
    return Drink(
      id: json['_id']?.toString(),
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      price: (json['price'] is int)
          ? json['price']
          : int.tryParse(json['price'].toString()) ?? 0,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating'].toString()) ?? 0.0,
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      options: (json['options'] != null)
          ? (json['options'] as List)
                .map((opt) => Option.fromJson(opt))
                .toList()
          : [],
    );
  }

  static String _generateTempId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(9999).toString();
  }
}

class CartItem {
  final Drink drink;
  final Option? option;
  int quantity;

  CartItem({required this.drink, this.option, this.quantity = 1});

  @override
  bool operator ==(Object other) {
    return other is CartItem &&
        other.drink.name == drink.name &&
        other.option?.name == option?.name;
  }

  @override
  int get hashCode => drink.name.hashCode ^ (option?.name.hashCode ?? 0);

  int get unitPrice => drink.price + (option?.extraPrice ?? 0);
  int get totalPrice => unitPrice * quantity;
}

int calculateCartTotal(List<CartItem> cartList) {
  return cartList.fold(0, (sum, item) => sum + item.totalPrice);
}

// 🌐 CONST: Base URL của server
const String BASE_URL = "http://10.0.2.2:5000";

// 🔄 Helper function để lấy URL ảnh từ server
String getImageUrl(String imagePath) {
  // Nếu đã là URL đầy đủ
  if (imagePath.startsWith('http')) {
    return imagePath;
  }

  // Nếu là đường dẫn server /uploads/...
  if (imagePath.startsWith('/uploads/')) {
    return "$BASE_URL$imagePath";
  }

  // Nếu là đường dẫn assets/... (fallback)
  if (imagePath.startsWith('assets/')) {
    return "$BASE_URL/uploads/${imagePath.replaceFirst('assets/', '')}";
  }

  // Mặc định
  return "$BASE_URL/uploads/$imagePath";
}
//------------------------------------------------------

// 🔄 Hàm đồng bộ sản phẩm có ảnh lên server
// Future<void> syncProductsToServer(List<Drink> products) async {
//   final url = Uri.parse("$BASE_URL/api/products/add-many");

//   try {
//     print("🚀 Bắt đầu đồng bộ ${products.length} sản phẩm...");

//     var request = http.MultipartRequest('POST', url);

//     // Thêm JSON data
//     request.fields['products'] = jsonEncode(
//       products.map((p) => p.toJson()).toList(),
//     );

//     // Upload từng ảnh
//     int successCount = 0;
//     for (var product in products) {
//       try {
//         // Loại bỏ dấu "/" đầu nếu có
//         String assetPath = product.image.startsWith('/')
//             ? product.image.substring(1)
//             : product.image;

//         // Đọc file từ assets
//         final ByteData data = await rootBundle.load(assetPath);
//         final Uint8List bytes = data.buffer.asUint8List();

//         // Tạo multipart file từ bytes
//         final multipartFile = http.MultipartFile.fromBytes(
//           'images',
//           bytes,
//           filename: path.basename(assetPath),
//         );

//         request.files.add(multipartFile);
//         successCount++;
//         print("✅ Đã thêm ảnh: $assetPath");
//       } catch (e) {
//         print("❌ Lỗi đọc ảnh ${product.image}: $e");
//       }
//     }

//     print("📤 Đang upload $successCount ảnh lên server...");

//     // Gửi request
//     var streamedResponse = await request.send();
//     var response = await http.Response.fromStream(streamedResponse);

//     if (response.statusCode == 201) {
//       print("✅ Đồng bộ thành công!");
//       final data = jsonDecode(response.body);
//       print("📊 Đã thêm ${data['count']} sản phẩm vào database");
//     } else {
//       print("❌ Lỗi đồng bộ: ${response.statusCode}");
//       print("📄 Chi tiết: ${response.body}");
//     }
//   } catch (e) {
//     print("⚠️ Lỗi kết nối server: $e");
//   }
// }

//-----------------------------------
// 📥 Lấy sản phẩm từ server
Future<List<Drink>> fetchProductsFromServer() async {
  final url = Uri.parse("$BASE_URL/api/products");

  try {
    print("📥 Đang tải sản phẩm từ server...");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> productsJson = jsonDecode(response.body);

      List<Drink> drinks = productsJson.map((json) {
        // Debug: In ra đường dẫn ảnh từ DB
        print("🖼️ Image from DB: ${json['image']}");
        return Drink.fromJson(json);
      }).toList();

      print("✅ Lấy thành công ${drinks.length} sản phẩm từ server");
      return drinks;
    } else {
      print("❌ Lỗi lấy dữ liệu: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    print("⚠️ Lỗi kết nối server: $e");
    return [];
  }
}

// 🗑️ Xóa tất cả sản phẩm (để sync lại)
Future<bool> deleteAllProducts() async {
  final url = Uri.parse("$BASE_URL/api/products/delete-all");

  try {
    final response = await http.delete(url);
    if (response.statusCode == 200) {
      print("✅ Đã xóa tất cả sản phẩm");
      return true;
    } else {
      print("❌ Lỗi xóa: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    print("⚠️ Lỗi kết nối: $e");
    return false;
  }
}

final List<Drink> products = [
  Drink(
    name: "Latte Almond",
    image: "assets/coffe/Latte_Almond.png",
    price: 59000,
    rating: 4.8,
    category: "Coffee",
    description:
        "Ngon miệng với vị béo bùi của sữa hạnh nhân kết hợp cùng espresso đậm đà."
        "- Cà phê espresso\n- Sữa hạnh nhân",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Shot Espresso", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Latte Caramel",
    image: "assets/coffe/Latte_Caramel.png",
    price: 59000,
    rating: 4.9,
    category: "Coffee",
    description:
        "Sự hoà quyện của sữa tươi béo ngậy và sốt caramel ngọt ngào.\n\n"
        "- Espresso\n- Sữa tươi\n- Sốt caramel",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Caramel", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Latte Hazelnut",
    image: "assets/coffe/Latte_Hazelnut.png",
    price: 59000,
    rating: 4.7,
    category: "Coffee",
    description:
        "Vị thơm béo của sữa tươi hòa cùng hương hạt dẻ Hazelnut nồng nàn.\n\n"
        "- Espresso\n- Sữa tươi\n- Syrup hạt dẻ",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Hazelnut Syrup", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Latte Coconut",
    image: "assets/coffe/Latte_Coconut.png",
    price: 59000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Thức uống mới lạ từ sự kết hợp giữa espresso đậm đà và sữa dừa béo thơm.\n\n"
        "- Espresso\n- Sữa dừa",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Cơm Dừa", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Latte Bạc Xỉu",
    image: "assets/coffe/Latte_Bac_Xiu.png",
    price: 49000,
    rating: 4.5,
    category: "Coffee",
    description:
        "Hương vị truyền thống quen thuộc của bạc xỉu – ngọt ngào và dễ uống.\n\n"
        "- Cà phê phin\n- Sữa đặc\n- Sữa tươi",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Latte Classic",
    image: "assets/coffe/Latte_Classic.png",
    price: 55000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Công thức Latte nguyên bản: espresso mạnh mẽ hòa quyện với sữa tươi béo ngậy.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Americano Nóng",
    image: "assets/coffe/Americano_Nong.png",
    price: 49000,
    rating: 4.8,
    category: "Coffee",
    description:
        "Cà phê đen phong cách Mỹ, chỉ đơn giản espresso pha loãng với nước nóng.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Cappuccino Nóng",
    image: "assets/coffe/Cappuccino_Nong.png",
    price: 55000,
    rating: 4.7,
    category: "Coffee",
    description:
        "Espresso, sữa nóng và lớp bọt sữa mịn màng – hương vị Ý truyền thống.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Cappuccino Đá",
    image: "assets/coffe/Cappuccino_Da.png",
    price: 55000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Phiên bản cappuccino mát lạnh với đá viên, cân bằng vị đắng – ngọt – béo.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Caramel Macchiato Nóng",
    image: "assets/coffe/Caramel_Macchiato_Nong.png",
    price: 55000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Espresso kết hợp sữa tươi và sốt caramel, mang đến hương vị ngọt ngào ấm áp.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Caramel Macchiato Đá",
    image: "assets/coffe/Caramel_Macchiato_Da.png",
    price: 65000,
    rating: 4.8,
    category: "Coffee",
    description:
        "Sự kết hợp hoàn hảo của espresso, sữa tươi mát lạnh và caramel ngọt ngào.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Espresso Nóng",
    image: "assets/coffe/Espresso_Nong.png",
    price: 45000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Một shot espresso nguyên bản – đậm đà, mạnh mẽ, dành cho tín đồ cà phê.",
    options: [
      Option(name: "Single Shot"),
      Option(name: "Double Shot", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Latte Nóng",
    image: "assets/coffe/Latte_Nong.png",
    price: 59000,
    rating: 4.6,
    category: "Coffee",
    description:
        "Latte nóng truyền thống – vị ngọt dịu và béo thơm, thích hợp cho mọi thời điểm.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),

  // 🍵 Tea
  Drink(
    name: "Oolong Tứ Quý Sen (Nóng)",
    image: "assets/tea/Oolong_Tu_Quy_Sen(Nong).png",
    price: 59000,
    rating: 4.8,
    category: "Tea",
    description:
        "Trà oolong Tứ Quý hảo hạng, kết hợp hương sen thơm thanh tao, dùng nóng cho vị dịu nhẹ.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Oolong Tứ Quý Sen",
    image: "assets/tea/Oolong_Tu_Quy_Sen.png",
    price: 49000,
    rating: 4.3,
    category: "Tea",
    description:
        "Hương vị tinh tế của trà oolong Tứ Quý, kết hợp cùng hương sen tự nhiên.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Oolong Tứ Dâu Trân Châu",
    image: "assets/tea/Oolong_Tu_Quy_Dau_Tran_Chau.png",
    price: 49000,
    rating: 4.3,
    category: "Tea",
    description:
        "Trà oolong Tứ Quý kết hợp hương dâu chua ngọt cùng trân châu dai giòn.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Oolong Tứ Quý Kim Quất Trân Châu",
    image: "assets/tea/Oolong_Tu_Quy_Kim_Quat_Tran_Chau.png",
    price: 49000,
    rating: 4.8,
    category: "Tea",
    description:
        "Vị trà oolong Tứ Quý thanh mát, hòa quyện cùng hương vị kim quất và topping trân châu.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Oolong Tứ Quý Vải",
    image: "assets/tea/Oolong_Tu_Quy_Vai.png",
    price: 49000,
    rating: 4.9,
    category: "Tea",
    description:
        "Trà oolong Tứ Quý thanh mát kết hợp hương vải ngọt ngào, dễ uống.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),

  // 🍫 Chocolate
  Drink(
    name: "Chocolate Đá",
    image: "assets/chocolate/Chocolate_Da.png",
    price: 55000,
    rating: 4.8,
    category: "Chocolate",
    description:
        "Sô-cô-la nguyên chất, pha lạnh cùng sữa tươi – vị ngọt đắng cân bằng hoàn hảo.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Kem Tươi", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Chocolate Nóng",
    image: "assets/chocolate/Chocolate_Nong.png",
    price: 55000,
    rating: 4.5,
    category: "Chocolate",
    description:
        "Ly sô-cô-la nóng hổi, ngọt ngào và ấm áp – lựa chọn hoàn hảo cho ngày lạnh.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Marshmallow", extraPrice: 8000),
    ],
  ),

  // 🧋 Milk Tea
  Drink(
    name: "Trà Sữa Oolong Nướng Sương Sáo",
    image: "assets/milktea/Tra_Sua_Oolong_Nuong_Suong_Sao.png",
    price: 55000,
    rating: 4.8,
    category: "Milk Tea",
    description:
        "Hương vị trà oolong nướng đậm đà, kết hợp cùng sữa thơm béo và sương sáo mát lạnh.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Trân Châu", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Trà Sữa Oolong Tứ Quý Sương Sáo",
    image: "assets/milktea/Tra_Sua_Oolong_Tu_Quy_Suong_Sao.png",
    price: 55000,
    rating: 4.8,
    category: "Milk Tea",
    description:
        "Trà oolong Tứ Quý kết hợp sữa tươi béo ngậy, topping sương sáo độc đáo.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Trân Châu", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Hồng Trà Sữa Nóng",
    image: "assets/milktea/Hong_Tra_Sua_Nong.png",
    price: 55000,
    rating: 4.5,
    category: "Milk Tea",
    description:
        "Hồng trà đậm vị, pha cùng sữa đặc và sữa tươi – phiên bản nóng đầy ấm áp.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
    ],
  ),
  Drink(
    name: "Hồng Trà Sữa Trân Châu",
    image: "assets/milktea/Hong_Tra_Sua_Tran_Chau.png",
    price: 55000,
    rating: 4.8,
    category: "Milk Tea",
    description:
        "Hồng trà kết hợp sữa tươi béo ngậy, thêm trân châu dẻo dai – hương vị quốc dân.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Trân Châu", extraPrice: 7000),
    ],
  ),
  Drink(
    name: "Trà Đen Macchiato",
    image: "assets/milktea/Tra_Den_Macchiato.png",
    price: 55000,
    rating: 4.2,
    category: "Milk Tea",
    description:
        "Hồng trà đen thơm mạnh, kết hợp lớp kem macchiato béo mặn nhẹ nhàng.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 5000),
      Option(name: "Size Lớn", extraPrice: 10000),
      Option(name: "Thêm Kem Macchiato", extraPrice: 8000),
    ],
  ),
  Drink(
    name: "Trà Sữa Oolong BLao",
    image: "assets/milktea/Tra_Sua_Oolong_BLao.png",
    price: 39000,
    rating: 4.1,
    category: "Milk Tea",
    description:
        "Trà oolong B'Lao đậm hương, pha cùng sữa thơm béo – giá hợp túi tiền, hương vị tuyệt vời.",
    options: [
      Option(name: "Size Nhỏ"),
      Option(name: "Size Vừa", extraPrice: 4000),
      Option(name: "Size Lớn", extraPrice: 8000),
    ],
  ),
];
