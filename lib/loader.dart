import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class loader extends StatelessWidget {
  const loader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      width: 300.0,
      height: 300.0,
      child: SpinKitRipple(
        color: Colors.blueAccent,

        // itemBuilder: (_, int index) {
        //   return DecoratedBox(
        //     decoration: BoxDecoration(
        //       color: index.isEven ? Colors.grey : Colors.blueAccent,
        //     ),
        //   );
        // },
        size: 120.0,
      ),
    );
  }
}