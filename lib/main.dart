import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const CirioApp());
}

class CirioApp extends StatelessWidget {
  const CirioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotas do Círio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MapaCirioScreen(),
    );
  }
}

class MapaCirioScreen extends StatefulWidget {
  const MapaCirioScreen({super.key});

  @override
  State<MapaCirioScreen> createState() => _MapaCirioScreenState();
}

class _MapaCirioScreenState extends State<MapaCirioScreen> {
 
  final LatLng catedralSe = const LatLng(-1.4558, -48.5044);
  final LatLng basilicaNazare = const LatLng(-1.4526, -48.4837);

  List<LatLng> rotaRuaPorRua = [];
  bool carregandoRota = false;
  String infoBarraTopo = "Mapa do Círio";

  
  LatLng? pontoInicioAtual;
  LatLng? pontoFimAtual;

  @override
  void initState() {
    super.initState();
    
    _buscarRotaNaAPI(catedralSe, basilicaNazare, "Círio de Nazaré");
  }

  
  Future<void> _buscarRotaNaAPI(
    LatLng origem,
    LatLng destino,
    String titulo,
  ) async {
    setState(() {
      carregandoRota = true;
      pontoInicioAtual = origem; 
      pontoFimAtual = destino; 
    });

    final String url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${origem.longitude},${origem.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?geometries=geojson&overview=full';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordsJson =
            data['routes'][0]['geometry']['coordinates'];

        final double distanciaMetros = data['routes'][0]['distance'].toDouble();
        final String distanciaKm = (distanciaMetros / 1000).toStringAsFixed(2);

        final List<LatLng> temporaryPoints = coordsJson
            .map((coord) => LatLng(coord[1], coord[0]))
            .toList();

        setState(() {
          rotaRuaPorRua = temporaryPoints;
          infoBarraTopo = "$titulo ($distanciaKm km)";
          carregandoRota = false;
        });
      } else {
        setState(() {
          carregandoRota = false;
          infoBarraTopo = "Erro ao buscar rota";
        });
      }
    } catch (e) {
      setState(() {
        carregandoRota = false;
        infoBarraTopo = "Erro de conexão";
      });
    }
  }


  Future<void> _tracarRotaDoGPSUsuario() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          infoBarraTopo = "Ligue o GPS do celular!";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            infoBarraTopo = "Permissão de GPS negada!";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          infoBarraTopo = "GPS bloqueado nas configurações.";
        });
        return;
      }

      setState(() {
        carregandoRota = true;
        infoBarraTopo = "Procurando satélites...";
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      LatLng localUsuario = LatLng(position.latitude, position.longitude);

 
      _buscarRotaNaAPI(localUsuario, catedralSe, "Sua distância até a Sé");
    } catch (erro) {
      setState(() {
        carregandoRota = false;
        infoBarraTopo = "Erro ao buscar GPS";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(infoBarraTopo),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: carregandoRota
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(initialCenter: catedralSe, initialZoom: 14.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.geo_location_cirio',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: rotaRuaPorRua,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    
                    if (pontoInicioAtual != null)
                      Marker(
                        point: pontoInicioAtual!,
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 50.0,
                        ),
                      ),
                    
                    if (pontoFimAtual != null)
                      Marker(
                        point: pontoFimAtual!,
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.flag_circle,
                          color: Colors.green,
                          size: 50.0,
                        ),
                      ),
                  ],
                ),
              ],
            ),

 
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          children: [
         
            ElevatedButton.icon(
              onPressed: () => _buscarRotaNaAPI(
                catedralSe,
                basilicaNazare,
                "Círio de Nazaré",
              ),
              icon: const Icon(Icons.wb_sunny, color: Colors.orange),
              label: const Text("Círio"),
            ),
           
            ElevatedButton.icon(
              onPressed: () =>
                  _buscarRotaNaAPI(basilicaNazare, catedralSe, "Trasladação"),
              icon: const Icon(Icons.nights_stay, color: Colors.indigo),
              label: const Text("Trasladação"),
            ),
           
            ElevatedButton.icon(
              onPressed: _tracarRotaDoGPSUsuario,
              icon: const Icon(Icons.my_location, color: Colors.blue),
              label: const Text("Meu GPS"),
            ),
          ],
        ),
      ),
    );
  }
}
