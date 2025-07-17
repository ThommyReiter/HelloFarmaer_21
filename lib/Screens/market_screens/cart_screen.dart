import 'package:flutter/material.dart';
import 'package:hellofarmer/Core/constants.dart';
import 'package:hellofarmer/Providers/cart_provider.dart';
import 'package:hellofarmer/Widgets/market_widgets/cart/cart_item_widget.dart';
import 'package:hellofarmer/Widgets/market_widgets/cart/cart_total_widget.dart';
import 'package:provider/provider.dart';
import 'package:hellofarmer/Model/custom_user.dart';

class CartScreen extends StatefulWidget {
  final CustomUser user; // Adicionado para passar o usuário

  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.items;

    final subtotal = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Meu Carrinho",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Constants.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Carrinho vazio'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: cartItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return CartItemWidget(
                        item: {
                          'name': item.product.nomeProduto,
                          'price': item.product.preco,
                          'quantity': item.quantity,
                          'image': item.product.imagem,
                          'inStock': true,
                        },
                        onQuantityChanged: (newQuantity) {
                          setState(() {
                            final dif = newQuantity - item.quantity;
                            if (dif > 0) {
                              cartProvider.incrementQuantity(index);
                            } else if (dif < 0) {
                              cartProvider.decrementQuantity(index);
                            }
                          });
                        },
                        onDelete: () {
                          setState(() {
                            cartProvider.removeProduct(index);
                          });
                        },
                      );
                    },
                  ),
                ),
                CartTotalWidget(cartItems: cartItems, subtotal: subtotal),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: cartItems.isEmpty
                        ? null
                        : () async {
                            try {
                              await cartProvider.checkout(widget.user);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Compra finalizada com sucesso!')),
                              );
                              Navigator.pop(context); // Voltar para a tela anterior
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao finalizar compra: $e')),
                              );
                            }
                          },
                    child: const Text(
                      'Finalizar Compra',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}