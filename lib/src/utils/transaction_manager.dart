import 'dart:convert';
import '../logger.dart';
import 'package:eventify/eventify.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ignore: unused_element
var _logger = getLogger('TransactionManager');

class TransactionManager extends EventEmitter {
  num maxId = 0;
  WebSocketChannel transport;
  Function? listener;
  String? sdp;
  TransactionManager(this.transport) {
    listener(dynamic msg) async {
      Map<String, dynamic> message;
      try {
        //Process message
        message = jsonDecode(msg as String) as Map<String, dynamic>;
      } catch (e) {
        //Emit it
        //Ignore it
        return;
      }
      //Check type
      switch (message['type']) {
        case 'cmd':
          //Create command
          Map<String, dynamic> cmd = {
            'name': message['name'],
            'data': message['data'],
            'accept': (data) => {
                  //Send response back
                  transport.sink.add({
                    'type': 'response',
                    'transId': message['transId'],
                    'data': data
                  })
                },
            'reject': (data) => {
                  //Send response back
                  transport.sink.add(jsonEncode({
                    'type': 'error',
                    'transId': message['transId'],
                    'data': data
                  }))
                }
          };
          emit('cmd', this, cmd);
          break;
        case 'response':
          {
            //emit response
            emit('response', this, message);
            break;
          }
        case 'error':
          {
            break;
          }
        case 'event':
          //Create event
          var event = {
            'name': message['name'],
            'data': message['data'],
          };

          emit('event', this, event);

          break;
        default:
      }
    }

    //Add it
    transport.stream.listen((event) => {listener(event)});
  }

  Future<dynamic> cmd(String? name, data) async {
    {
      Map<String, dynamic> cmd = {
        'type': 'cmd',
        'transId': maxId++,
        'name': name,
        'data': data
      };
      //Serialize
      String json = jsonEncode(cmd);
      //Check name is correct
      if (name == null || name.isEmpty) {
        throw Exception('Bad command name');
      }
      try {
        //Send json
        transport.sink.add(json);
        return (cmd['transId']);
        //Add callbacks
      } catch (e) {
        //rethrow
        throw Exception(e);
      }
    }
  }

  event(name, data) {
    //Check name is correct
    if (!name || name.length == 0) {
      throw Exception('Bad event name');
    }

    //Create command
    Map event = {'type': 'event', 'name': name, 'data': data};
    //Serialize
    String json = jsonEncode(event);
    //Send json
    transport.sink.add(json);
  }

  close() {
    //remove listeners
    transport.sink.close();
  }
}