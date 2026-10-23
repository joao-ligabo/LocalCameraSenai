import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Perfil com Foto e Localização',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const TelaPerfil(),
    );
  }
}

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  // Foto do perfil.
  File? foto;

  // Dados da localização.
  String localizacao = 'Localização ainda não obtida';
  String endereco = 'Endereço ainda não identificado';

  LatLng? coordenada;

  bool localizacaoObtida = false;
  bool buscandoLocalizacao = false;

  // Seleciona uma foto pela câmera ou galeria.
  Future<void> escolherFoto(ImageSource origem) async {
    try {
      final picker = ImagePicker();

      final imagem = await picker.pickImage(
        source: origem,
      );

      if (!mounted) return;

      if (imagem != null) {
        setState(() {
          foto = File(imagem.path);
        });
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível selecionar a imagem.',
          ),
        ),
      );
    }
  }

  // Remove a foto do perfil.
  void removerFoto() {
    setState(() {
      foto = null;
    });
  }

  // Obtém a localização atual do dispositivo.
  Future<void> obterLocalizacao() async {
    setState(() {
      buscandoLocalizacao = true;
      endereco = 'Buscando cidade, estado e país...';
    });

    try {
      final servicoAtivo =
          await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        atualizarErroLocalizacao(
          'Ative o GPS ou serviço de localização.',
        );
        return;
      }

      var permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied) {
        atualizarErroLocalizacao(
          'Permissão de localização negada.',
        );
        return;
      }

      if (permissao == LocationPermission.deniedForever) {
        atualizarErroLocalizacao(
          'Permissão negada permanentemente. '
          'Libere-a nas configurações do aplicativo.',
        );
        return;
      }

      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      if (!mounted) return;

      setState(() {
        coordenada = LatLng(
          posicao.latitude,
          posicao.longitude,
        );

        localizacao =
            'Latitude: ${posicao.latitude.toStringAsFixed(4)}\n'
            'Longitude: ${posicao.longitude.toStringAsFixed(4)}';

        localizacaoObtida = true;
      });

      // Converte as coordenadas em um endereço.
      await buscarEndereco(
        posicao.latitude,
        posicao.longitude,
      );
    } catch (_) {
      atualizarErroLocalizacao(
        'Não foi possível obter a localização.',
      );
    } finally {
      if (mounted) {
        setState(() {
          buscandoLocalizacao = false;
        });
      }
    }
  }

  // Consulta o Nominatim para descobrir o endereço.
  Future<void> buscarEndereco(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'addressdetails': '1',
          'accept-language': 'pt-BR',
        },
      );

      final resposta = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'cameralocalizacaoflutter/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resposta.statusCode != 200) {
        throw Exception('Falha na consulta do endereço.');
      }

      final dados = jsonDecode(
        utf8.decode(resposta.bodyBytes),
      ) as Map<String, dynamic>;

      final componentes =
          dados['address'] as Map<String, dynamic>?;

      if (componentes == null) {
        throw Exception('Endereço não encontrado.');
      }

      // A cidade pode aparecer com nomes diferentes
      // dependendo da região.
      final cidade = componentes['city'] ??
          componentes['town'] ??
          componentes['village'] ??
          componentes['municipality'] ??
          componentes['city_district'] ??
          componentes['county'];

      final estado = componentes['state'];
      final pais = componentes['country'];

      if (!mounted) return;

      setState(() {
        endereco =
            'Cidade: ${cidade ?? "Não identificada"}\n'
            'Estado: ${estado ?? "Não identificado"}\n'
            'País: ${pais ?? "Não identificado"}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        endereco =
            'Não foi possível identificar o endereço.\n'
            'Confira sua conexão e tente novamente.';
      });
    }
  }

  // Apresenta mensagens de erro de localização.
  void atualizarErroLocalizacao(String mensagem) {
    if (!mounted) return;

    setState(() {
      localizacao = mensagem;
      endereco = 'Endereço indisponível';
      localizacaoObtida = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil com Foto e Localização',
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Foto de perfil.
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  foto != null ? FileImage(foto!) : null,
              child: foto == null
                  ? const Icon(
                      Icons.person,
                      size: 60,
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // Tirar foto.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    escolherFoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar foto'),
              ),
            ),

            const SizedBox(height: 8),

            // Escolher ou trocar foto pela galeria.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    escolherFoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text(
                  'Escolher ou trocar foto',
                ),
              ),
            ),

            // Remover foto.
            if (foto != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: removerFoto,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover foto'),
              ),
            ],

            const SizedBox(height: 28),

            // Ícone de localização.
            Icon(
              localizacaoObtida
                  ? Icons.location_on
                  : Icons.location_searching,
              size: 42,
              color: localizacaoObtida
                  ? Colors.green
                  : Colors.grey,
            ),

            const SizedBox(height: 12),

            // Latitude e longitude.
            Text(
              localizacao,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            // Cidade, estado e país.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.public,
                        size: 30,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Endereço aproximado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        endereco,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Obter ou atualizar localização.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: buscandoLocalizacao
                    ? null
                    : obterLocalizacao,
                icon: buscandoLocalizacao
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  buscandoLocalizacao
                      ? 'Obtendo localização...'
                      : localizacaoObtida
                          ? 'Atualizar localização'
                          : 'Usar minha localização',
                ),
              ),
            ),

            // Mapa do OpenStreetMap.
            if (coordenada != null) ...[
              const SizedBox(height: 24),

              const Text(
                'Minha localização no mapa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: coordenada!,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'cameralocalizacaoflutter',
                      ),

                      MarkerLayer(
                        markers: [
                          Marker(
                            point: coordenada!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
