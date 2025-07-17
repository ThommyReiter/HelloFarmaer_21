import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hellofarmer/Model/cart_item.dart';
import 'package:hellofarmer/Model/produtos.dart';
import 'package:hellofarmer/Model/custom_user.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _cartItens = [];
  List<CartItem> get items => _cartItens;
  int get itemCount => _cartItens.length;

  double get totalPrice {
    double total = 0.0;
    for (var item in _cartItens) {
      total += item.totalPrice;
    }
    return total;
  }

  void addProduct(Produtos product) {
    final existingItemIndex = _cartItens.indexWhere((item) => item.product.idProduto == product.idProduto);
    if (existingItemIndex >= 0) {
      _cartItens[existingItemIndex].quantity++;
    } else {
      _cartItens.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeProduct(int index) {
    _cartItens.removeAt(index);
    notifyListeners();
  }

  void incrementQuantity(int index) {
    _cartItens[index].quantity++;
    notifyListeners();
  }

  void decrementQuantity(int index) {
    if (_cartItens[index].quantity > 1) {
      _cartItens[index].quantity--;
    } else {
      _cartItens.removeAt(index);
    }
    notifyListeners();
  }

  void clearCart() {
    _cartItens.clear();
    notifyListeners();
  }

  Future<bool> checkStockAvailability() async {
    FirebaseApp firebaseApp;
    try {
      firebaseApp = Firebase.app();
    } catch (e) {
      throw Exception('Erro ao acessar instância do Firebase: $e');
    }

    final databaseRef = FirebaseDatabase.instanceFor(
      app: firebaseApp,
      databaseURL: 'https://hello-farmer-cm-2025-c2db6-default-rtdb.europe-west1.firebasedatabase.app/',
    );

    for (var item in _cartItens) {
      final snapshot = await databaseRef.ref('products/${item.product.idProduto}').get();
      if (!snapshot.exists) {
        return false;
      }
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final currentStock = (data['quantidade'] is int)
          ? (data['quantidade'] as int).toDouble()
          : data['quantidade']?.toDouble() ?? 0.0;
      if (currentStock < item.quantity) {
        return false;
      }
    }
    return true;
  }

  Future<void> checkout(CustomUser user) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Usuário não autenticado. Por favor, faça login.');
    }

    if (!(await checkStockAvailability())) {
      throw Exception('Um ou mais produtos estão fora de estoque.');
    }

    FirebaseApp firebaseApp;
    try {
      firebaseApp = Firebase.app();
    } catch (e) {
      throw Exception('Erro ao acessar instância do Firebase: $e');
    }

    final databaseRef = FirebaseDatabase.instanceFor(
      app: firebaseApp,
      databaseURL: 'https://hello-farmer-cm-2025-c2db6-default-rtdb.europe-west1.firebasedatabase.app/',
    );

    try {
      // Criar um novo ID para o pedido
      final orderId = databaseRef.ref('orders').push().key;
      final orderData = {
        'idOrder': orderId,
        'userId': user.idUser,
        'items': _cartItens.map((item) => {
              'idProduto': item.product.idProduto,
              'nomeProduto': item.product.nomeProduto,
              'quantidade': item.quantity,
              'preco': item.product.preco,
            }).toList(),
        'data': DateTime.now().toIso8601String(),
        'status': 'pendente',
      };

      // Atualizar o stock de cada produto usando transação
      for (var item in _cartItens) {
        final productRef = databaseRef.ref('products/${item.product.idProduto}');
        await productRef.runTransaction((currentData) {
          if (currentData == null) {
            return Transaction.abort();
          }
          final data = Map<String, dynamic>.from(currentData as Map);
          final currentStock = (data['quantidade'] is int)
              ? (data['quantidade'] as int).toDouble()
              : data['quantidade']?.toDouble() ?? 0.0;

          if (currentStock < item.quantity) {
            throw Exception('Estoque insuficiente para ${item.product.nomeProduto}');
          }

          data['quantidade'] = currentStock - item.quantity;
          data['comprado'] = (data['comprado'] ?? 0) + 1;
          return Transaction.success(data);
        });
      }

      // Registrar o pedido no nó orders
      await databaseRef.ref('orders/$orderId').set(orderData);

      // Limpar o carrinho
      clearCart();
    } catch (e) {
      print('Erro ao processar compra: $e');
      rethrow;
    }
  }
}