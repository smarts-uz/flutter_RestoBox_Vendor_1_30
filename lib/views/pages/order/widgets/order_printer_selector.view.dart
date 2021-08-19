import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:fuodz/constants/app_strings.dart';
import 'package:fuodz/models/order.dart';
import 'package:fuodz/translations/order_details.i18n.dart';
import 'package:fuodz/utils/ui_spacer.dart';
import 'package:fuodz/widgets/custom_list_view.dart';
import 'package:velocity_x/velocity_x.dart';

class OrderPrinterSelector extends StatefulWidget {
  OrderPrinterSelector(this.order, {Key key}) : super(key: key);
  final Order order;

  @override
  _OrderPrinterSelectorState createState() => _OrderPrinterSelectorState();
}

class _OrderPrinterSelectorState extends State<OrderPrinterSelector> {
  //START ORDER PRINTING STUFFS
  PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  List<PrinterBluetooth> _devices = [];
  String _devicesMsg;
  BluetoothManager bluetoothManager = BluetoothManager.instance;

  //
  final bigTextStyle = PosStyles(width: PosTextSize.size5);
  final mediumTextStyle = PosStyles(width: PosTextSize.size3);
  final smallTextStyle = PosStyles(width: PosTextSize.size2);

  @override
  void initState() {
    if (Platform.isIOS) {
      initPrinter();
    } else {
      bluetoothManager.state.listen((val) {
        print("state = $val");
        if (!mounted) return;
        if (val == 12) {
          print('on');
          initPrinter();
        } else if (val == 10) {
          print('off');
          setState(() {
            _devicesMsg = 'Please enable bluetooth to print';
          });
        }
        print('state is $val');
      });
    }
    super.initState();
  }

  //
  initPrinter() {
    print('init printer');

    _printerManager.startScan(Duration(seconds: 2));
    _printerManager.scanResults.listen((event) {
      if (!mounted) return;
      setState(() => _devices = event);

      if (_devices.isEmpty)
        setState(() {
          _devicesMsg = 'No devices';
        });
    });
  }

  Future<void> _startPrint(PrinterBluetooth printer) async {
    _printerManager.selectPrinter(printer);
    final myTicket = await _ticket(PaperSize.mm58);
    final result = await _printerManager.printTicket(myTicket);
    print(result);
  }

  Future<Ticket> _ticket(PaperSize paper) async {
    final ticket = Ticket(paper);
    ticket.text(widget.order.vendor.name, styles: bigTextStyle);
    ticket.text(widget.order.vendor.address, styles: smallTextStyle);
    ticket.hr();
    ticket.row([
      PosColumn(text: "Code".i18n, styles: smallTextStyle),
      PosColumn(text: "${widget.order.code}", styles: mediumTextStyle),
    ]);
    ticket.row([
      PosColumn(text: "Status".i18n, styles: smallTextStyle),
      PosColumn(
          text: "${widget.order.status}".allWordsCapitilize(),
          styles: mediumTextStyle),
    ]);
    ticket.row([
      PosColumn(text: "Customer".i18n, styles: smallTextStyle),
      PosColumn(
          text: "${widget.order.user.name}".allWordsCapitilize(),
          styles: mediumTextStyle),
    ]);

    //parcel order
    if (widget.order.isPackageDelivery) {
      ticket.row([
        PosColumn(text: "Pickup Location".i18n, styles: smallTextStyle),
        PosColumn(
            text: "${widget.order.user.name}".allWordsCapitilize(),
            styles: mediumTextStyle),
      ]);
      ticket.row([
        PosColumn(text: "Drop off Location".i18n, styles: smallTextStyle),
        PosColumn(
            text: "${widget.order.user.name}".allWordsCapitilize(),
            styles: mediumTextStyle),
      ]);
    } else {
      ticket.row([
        PosColumn(text: "Delievery Address".i18n, styles: smallTextStyle),
        PosColumn(
            text: "${widget.order?.deliveryAddress?.name}",
            styles: mediumTextStyle),
      ]);
    }
    ticket.hr();
    //title for next section
    ticket.text(
      (widget.order.isPackageDelivery ? "Package Details" : "Products").i18n,
    );
    ticket.emptyLines(1);

    //order product/package details
    if (widget.order.isPackageDelivery) {
      ticket.row([
        PosColumn(text: "Package Type".i18n, styles: smallTextStyle),
        PosColumn(
            text: "${widget.order.packageType.name}", styles: mediumTextStyle),
      ]);
      ticket.row([
        PosColumn(text: "Width".i18n, styles: smallTextStyle),
        PosColumn(text: widget.order.width + "cm", styles: mediumTextStyle),
      ]);
      ticket.row([
        PosColumn(text: "Length".i18n, styles: smallTextStyle),
        PosColumn(text: widget.order.length + "cm", styles: mediumTextStyle),
      ]);
      ticket.row([
        PosColumn(text: "Height".i18n, styles: smallTextStyle),
        PosColumn(text: widget.order.height + "cm", styles: mediumTextStyle),
      ]);
      ticket.row([
        PosColumn(text: "Weight".i18n, styles: smallTextStyle),
        PosColumn(text: widget.order.weight + "kg", styles: mediumTextStyle),
      ]);
    } else {
      //products
      for (var orderProduct in widget.order.orderProducts) {
        //
        ticket.row([
          PosColumn(
              text: "${orderProduct.product.name}", styles: mediumTextStyle),
          PosColumn(
            text:
                "${AppStrings.currencySymbol}${orderProduct.price.numCurrency}",
            styles: mediumTextStyle,
          )
        ]);
        //product options
        if (orderProduct.options != null) {
          ticket.row([
            PosColumn(
                text: "${orderProduct.product.name}", styles: mediumTextStyle),
            PosColumn(
              text: "${orderProduct.options}",
              styles: smallTextStyle,
            )
          ]);
        }
      }
    }
    //
    ticket.hr();
    ticket.emptyLines(2);
    ticket.row([
      PosColumn(text: "Note".i18n, styles: smallTextStyle),
      PosColumn(text: "${widget.order.note}", styles: mediumTextStyle),
    ]);
    ticket.emptyLines(2);
    ticket.cut();
    return ticket;
  }

  ///view
  @override
  Widget build(BuildContext context) {
    return VStack(
      [
        "Select Printer".i18n.text.semiBold.xl2.make(),
        UiSpacer.verticalSpace(),
        //printers
        _devices.isNotEmpty
            ? CustomListView(
                dataSet: _devices,
                itemBuilder: (context, index) {
                  //
                  final device = _devices[index];
                  return "${device.name}".text.make().py12().onInkTap(
                        () => _startPrint(device),
                      );
                },
              )
            : (_devicesMsg ?? 'Ops something went wrong!')
                .i18n
                .text
                .xl
                .makeCentered(),
      ],
    ).p20();
  }
}
