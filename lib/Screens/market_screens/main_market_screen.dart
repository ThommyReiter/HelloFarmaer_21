import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hellofarmer/Model/produtos.dart';
import 'package:hellofarmer/Core/constants.dart';
import 'package:hellofarmer/Model/custom_user.dart';
import 'package:hellofarmer/Providers/cart_provider.dart';
import 'package:hellofarmer/Widgets/market_widgets/search_box.dart';
import 'package:hellofarmer/Widgets/market_widgets/product_card.dart';
import 'package:hellofarmer/Screens/market_screens/cart_screen.dart';
import 'package:hellofarmer/Screens/market_screens/favorites_screen.dart';
import 'package:hellofarmer/Widgets/market_widgets/category_selector.dart';
import 'package:hellofarmer/Widgets/market_widgets/category_horizontal_list.dart';

class MarketScreen extends StatefulWidget {
  final CustomUser user;

  const MarketScreen({super.key, required this.user});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _currentIndex = 0;
  int _selectedCategory = 0;

  final List<String> categories = ['Todos', 'Ofertas', 'Vegetais', 'Frutas'];

  List<Produtos> _filteredProducts = [];
  List<Produtos> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProdutos();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProdutos() async {
    final produtos = await fetchProdutosFromFirebase();
    setState(() {
      _allProducts = produtos;
      _filteredProducts = produtos;
      _isLoading = false;
    });
  }

  Future<List<Produtos>> fetchProdutosFromFirebase() async {
    final databaseRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://hello-farmer-cm-2025-c2db6-default-rtdb.europe-west1.firebasedatabase.app/',
    ).ref('products');

    final snapshot = await databaseRef.get();

    List<Produtos> produtos = [];

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        try {
          final produto = Produtos.fromJson(Map<String, dynamic>.from(value));
          produtos.add(produto);
        } catch (e) {
          print('Erro ao converter produto: $e');
        }
      });
    }

    return produtos;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _selectedCategory == 0
            ? List.from(_allProducts)
            : _allProducts
                .where((p) => p.categoria == categories[_selectedCategory])
                .toList();
      } else {
        _filteredProducts = _allProducts.where((p) {
          final title = p.nomeProduto.toLowerCase();
          final category = p.categoria.toLowerCase();
          return title.contains(query) || category.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        title: const Text(
          "Mercado",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchBox(
                        controller: _searchController,
                        onSubmitted: (pesquisa) {
                          debugPrint('Pesquisa executada: $pesquisa');
                        },
                      ),
                      CategorySelector(
                        categories: categories,
                        selectedIndex: _selectedCategory,
                        onSelected: (index) {
                          setState(() {
                            _selectedCategory = index;
                            _onSearchChanged();
                          });
                        },
                      ),
                      if (_selectedCategory == 0 &&
                          _searchController.text.isEmpty)
                        ...categories.skip(1).map((category) {
                          final catProducts = _allProducts
                              .where((p) => p.categoria == category)
                              .toList();

                          if (catProducts.isEmpty) return const SizedBox.shrink();
                          return CategoryHorizontalList(
                            categoryName: category,
                            products: catProducts,
                            onShowAll: () {
                              final index = categories.indexOf(category);
                              if (index != -1) {
                                setState(() {
                                  _selectedCategory = index;
                                  _onSearchChanged();
                                });
                              }
                              debugPrint('Mostrar todos os produtos da categoria: $category');
                            },
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _filteredProducts.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nenhum produto encontrado.',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                )
                              : Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: _filteredProducts
                                      .map(
                                        (product) => SizedBox(
                                          width:
                                              (MediaQuery.of(context).size.width / 2) - 24,
                                          child: ProductCard(product: product),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_basket),
          label: 'Mercado',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_shopping_cart),
          label: 'Carrinho',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Favoritos',
        ),
      ],
      currentIndex: _currentIndex,
      selectedItemColor: Constants.primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _currentIndex = index;

          switch (_currentIndex) {
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartScreen(user: widget.user)),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesScreen()),
              );
              break;
          }
        });
      },
    );
  }
}