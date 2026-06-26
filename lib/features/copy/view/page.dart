import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/base/base_state_page.dart';
import 'package:instant_share/features/copy/provider/provider.dart';

class Page extends StatefulWidget {
  const Page({super.key});

  @override
  State<Page> createState() => _PageState();
}

class _PageState extends BaseStatePage<Page> {
  late final CopyProvider provider;

  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    provider = ref.watch(copyProvider);
    return const SizedBox.shrink();
  }
}
