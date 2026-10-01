import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'product_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../services/cart_service.dart';
import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String? username;
  const HomeScreen({super.key, this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  final PageController pageController = PageController();

  // Lab - Chat enhancement: Chat is the 2nd BottomNavigationBar tab
  // (Shop / Chat / Profile). Cart, which used to sit here, now lives behind
  // a cart icon in the AppBar instead (next to Settings).
  static const int _chatTabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          backgroundColor: Colors.blue.shade900,
          title: selectedIndex == 0
              ? Image.asset('assets/images/exchange_logo.png', scale: 11.3)
              : CustomText(
                  text: selectedIndex == _chatTabIndex ? 'Chats' : 'Profile',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          actions: [
            IconButton(
              icon: ValueListenableBuilder<Map<int, int>>(
                valueListenable: cartQuantities,
                builder: (context, quantities, _) {
                  final count = quantities.values.fold<int>(
                    0,
                    (sum, qty) => sum + qty,
                  );
                  return Badge(
                    label: Text('$count'),
                    isLabelVisible: count > 0,
                    child: Icon(Icons.shopping_cart, size: 24.sp),
                  );
                },
              ),
              onPressed: () => _openCart(context),
            ),
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        // Chat enhancement: ChatScreen is the tab at index 1 (Shop / Chat /
        // Profile), replacing Cart's old slot there.
        // Lab 4 - Enhancement 3: the Profile tab now renders the signed-in
        // user's saved data via ProfileScreen instead of a placeholder.
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: pageController,
          children: const [ProductScreen(), ChatScreen(), ProfileScreen()],
          onPageChanged: (page) {
            setState(() {
              selectedIndex = page;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shop), label: 'Shop'),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: selectedIndex,
          onTap: (int value) {
            setState(() {
              selectedIndex = value;
              pageController.jumpToPage(value);
            });
          },
        ),
      ),
    );
  }

  void _openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }
}
