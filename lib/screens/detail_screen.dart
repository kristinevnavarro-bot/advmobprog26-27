import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/user_services.dart';
import '../widgets/custom_text.dart';

// Enhancement 1: renamed from Lab 2's product_details_screen.dart to
// detail_screen.dart and given an optional productId constructor so it can
// be the single shared destination for both ProductScreen (which already
// has a full Product in hand) and CartScreen (which only has a product id)
// — both routes land on this same detail_screen.dart widget.
class DetailScreen extends StatelessWidget {
  final Product? product;
  final int? productId;

  const DetailScreen({super.key, this.product, this.productId})
      : assert(product != null || productId != null,
            'DetailScreen needs either a product or a productId');

  @override
  Widget build(BuildContext context) {
    if (product != null) {
      return _DetailBody(product: product!);
    }

    // fetch product by id so we can display the full product details
    return Scaffold(
      body: FutureBuilder<Product>(
        future: ProductService().getProductById(productId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: CustomText(
                text: 'Failed to load product: ${snapshot.error}',
                fontSize: 14.sp,
              ),
            );
          }
          return _DetailBody(product: snapshot.data!);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Product product;

  const _DetailBody({required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.h,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                product.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: Icon(Icons.image, size: 48.sp),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: product.title,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      CustomText(
                        text: '\$${product.price.toStringAsFixed(2)}',
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.star, size: 16.sp, color: Colors.amber),
                      SizedBox(width: 4.w),
                      CustomText(
                        text: product.rating.toStringAsFixed(1),
                        fontSize: 13.sp,
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    text: '${product.brand} · ${product.category}',
                    fontSize: 12.sp,
                  ),
                  SizedBox(height: 16.h),
                  CustomText(
                    text: 'Description',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: 6.h),
                  CustomText(text: product.description, fontSize: 13.sp),
                  SizedBox(height: 16.h),
                  CustomText(
                    text: 'Stock: ${product.stock} available',
                    fontSize: 12.sp,
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      // Enhancement 3: add-to-cart via POST /carts/add,
                      // passing the current user id and this product's id
                      // (quantity 1) as described in the dummyjson docs.
                      onPressed: () async {
                        try {
                          // Lab 4 - Enhancement 3: adds to the signed-in
                          // user's cart instead of a hardcoded userId.
                          final userId =
                              await UserService().getCurrentUserId();
                          await CartService().addToCart(
                            userId,
                            [
                              {'id': product.id, 'quantity': 1},
                            ],
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add: $e')),
                            );
                          }
                        }
                      },
                      child: const CustomText(
                        text: 'Add to Cart',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}