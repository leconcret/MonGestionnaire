import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await initializeDateFormatting('fr_FR', null);

  runApp(const MonGestionnaireApp());
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool isLoading = false;

  bool numeroValide(String numero) {
    return RegExp(r'^(07|05|01)[0-9]{8}$').hasMatch(numero);
  }

  bool pinValide(String pin) {
    return RegExp(r'^[0-9]{4}$').hasMatch(pin);
  }

  String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> connecterOuCreerCompte() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final telephone = telephoneController.text.trim();
    final pin = pinController.text.trim();

    if (!numeroValide(telephone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez svp entrer un numéro valide"),
        ),
      );

      setState(() {
        isLoading = false;
      });

      return;
    }

    if (!pinValide(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer un code PIN à 4 chiffres"),
        ),
      );

      setState(() {
        isLoading = false;
      });

      return;
    }

    
  final prefs = await SharedPreferences.getInstance();

final pinKey = "pinLocal_$telephone";
final ancienPinHash = prefs.getString(pinKey);
final pinHash = hashPin(pin);

if (ancienPinHash != null && ancienPinHash != pinHash) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Code PIN incorrect"),
    ),
  );

  setState(() {
    isLoading = false;
  });

  return;
}

if (ancienPinHash == null) {
  await prefs.setString(pinKey, pinHash);
}

await prefs.setString(
  "telephoneConnecte",
  telephone,
);

if (!mounted) return;

setState(() {
  isLoading = false;
});

Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const MainNavigation(),
  ),
);

synchroniserCompteFirebase(
  telephone,
  pin,
);

}

  Future<void> synchroniserCompteFirebase(
    String telephone,
    String pin,
  ) async {
    try {
      final compteRef = FirebaseFirestore.instance
          .collection("comptes")
          .doc(telephone);

      final compteDoc = await compteRef.get();

      final pinHash = hashPin(pin);

      if (!compteDoc.exists) {
        await compteRef.set({
          "telephone": telephone,
          "pinHash": pinHash,
          "createdAt": DateTime.now().toString(),
        });
      }
    } catch (e) {
      print("Synchronisation compte impossible : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/logo.png",
                height: 120,
              ),
              const SizedBox(height: 25),
              const Text(
                "Bienvenue",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B8E3E),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Votre assistant financier personnel",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD4A017),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: telephoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Numéro de téléphone",
                  hintText: "Ex : 07XXXXXXXX",
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: "PIN",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : connecterOuCreerCompte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B8E3E),
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Continuer",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class MonGestionnaireApp extends StatelessWidget {
  const MonGestionnaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Mon Gestionnaire",
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const LoginPage(),
    );
  }
}

class TransactionItem {
  final String id;
  final String type;
  final String categorie;
  final String moyenPaiement;
  final String description;
  final double montant;
  final String date;

  TransactionItem({
    required this.id,
    required this.type,
    required this.categorie,
    required this.moyenPaiement,
    required this.description,
    required this.montant,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "type": type,
      "categorie": categorie,
      "moyenPaiement": moyenPaiement,
      "description": description,
      "montant": montant,
      "date": date,
    };
  }

  static TransactionItem fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: map["type"],
      categorie: map["categorie"],
      moyenPaiement: map["moyenPaiement"],
      description: map["description"],
      montant: map["montant"],
      date: map["date"],
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() =>
      _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

   bool chargementDonnees = true;

Future<void> deconnexion() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.remove("telephoneConnecte");
  

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginPage(),
    ),
  );
}

  List<TransactionItem> transactions = [];

  @override
  void initState() {
    super.initState();
    chargerDonnees();
  }

  Future<void> chargerDonnees() async {

  setState(() {
    chargementDonnees = true;
  });

  await chargerTransactions();

  if (mounted) {
    setState(() {
      chargementDonnees = false;
    });
  }

  try {
    await sauvegarderTransactionsCloud();
  } catch (e) {
    print(
      "Synchronisation cloud impossible : $e",
    );
  }
}

  Future<void> chargerTransactions() async {
  final prefs = await SharedPreferences.getInstance();

  final telephone = prefs.getString("telephoneConnecte");

  if (telephone == null) return;

  List<String>? data = prefs.getStringList(
    "transactions_$telephone",
  );

  if (data != null) {
    transactions = data
        .map((e) => TransactionItem.fromMap(jsonDecode(e)))
        .toList();
  } else {
    transactions = [];
  }
}

  Future<void> sauvegarderTransactions() async {
  final prefs = await SharedPreferences.getInstance();

  final telephone = prefs.getString("telephoneConnecte");

  if (telephone == null) return;

  List<String> data = transactions
      .map((e) => jsonEncode(e.toMap()))
      .toList();

  await prefs.setStringList(
    "transactions_$telephone",
    data,
  );
}

  Future<void> sauvegarderTransactionsCloud() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final telephone =
        prefs.getString(
      "telephoneConnecte",
    );

    if (telephone == null) {
      print(
        "Aucun téléphone connecté",
      );
      return;
    }

    if (transactions.isEmpty) {
      print(
        "Aucune transaction locale à synchroniser",
      );
      return;
    }

    final collection =
        FirebaseFirestore.instance
            .collection(
              "comptes",
            )
            .doc(
              telephone,
            )
            .collection(
              "transactions",
            );

    for (var t in transactions) {
      await collection
          .doc(t.id)
          .set(
            t.toMap(),
          );
    }

    print(
      "Transactions synchronisées avec succès",
    );
  } catch (e) {
    print(
      "Erreur synchronisation transactions : $e",
    );
  }
}

  Future<void> chargerTransactionsCloud() async {
    final prefs =
    await SharedPreferences.getInstance();

final telephone =
    prefs.getString(
      "telephoneConnecte",
    );

if (telephone == null) return;

final collection =
    FirebaseFirestore.instance
        .collection("comptes")
        .doc(telephone)
        .collection(
          "transactions",
        );

    final snapshot = await collection.get();

    List<TransactionItem> dataCloud = snapshot.docs.map((doc) {
      return TransactionItem.fromMap(doc.data());
    }).toList();

    if (dataCloud.isNotEmpty) {
      transactions = dataCloud;
      await sauvegarderTransactions();
    }
  }

  @override
Widget build(BuildContext context) {
  List<Widget> pages = [
    HomePage(
      transactions: transactions,
      onChanged: () async {
        await sauvegarderTransactions();
        await sauvegarderTransactionsCloud();

        setState(() {});
      },
    ),
    StatistiquesPage(
      transactions: transactions,
    ),
    EpargnePage(
      transactions: transactions,
    ),
  ];

  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.green,
      elevation: 0,
      title: const SizedBox(),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.logout,
            color: Colors.black87,
          ),
          onPressed: deconnexion,
        ),
      ],
    ),
    body: chargementDonnees
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : pages[currentIndex],
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.green,
      onTap: (index) {
        setState(() {
          currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: "Statistiques",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.savings),
          label: "Épargne",
        ),
      ],
    ),
  );
}
}
class HomePage extends StatefulWidget {

  final List<TransactionItem> transactions;
  final VoidCallback onChanged;

  const HomePage({
    super.key,
    required this.transactions,
    required this.onChanged,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {

  String recherche = "";

  final List<String> categoriesEntree = [
    "Salaire",
    "Business",
    "Don",
    "Autre",
  ];

  final List<String> categoriesSortie = [
    "Loyer",
    "Education",
    "Santé",
    "Famille",
    "Épargne",
    "Don",
    "Transport",
    "Facture",
    "Data / Appels",
    "Shopping",
    "Loisir",
    "Popote",
    "Restaurant",
    "Maquis",
    "Autre",
  ];

  final List<String> moyensPaiement = [
    "Orange Money",
    "MTN Money",
    "Moov Money",
    "Wave",
    "Espèces",
    "Banque",
  ];

  String formatMontant(double montant) {

    return NumberFormat(
      "#,##0",
      "fr_FR",
    ).format(montant);
  }

  String formatDate(String date) {

    DateTime d = DateTime.parse(date);

    return DateFormat(
      "EEEE d MMMM yyyy • HH:mm",
      "fr_FR",
    ).format(d);
  }

  double get totalEntrees {

    return widget.transactions
        .where((t) => t.type == "Entrée")
        .fold(0, (s, t) => s + t.montant);
  }

  double get totalSorties {

    return widget.transactions
        .where((t) => t.type == "Sortie")
        .fold(0, (s, t) => s + t.montant);
  }

  double get totalEpargne {
  return widget.transactions
      .where(
        (t) =>
            t.type == "Sortie" &&
            t.categorie == "Épargne",
      )
      .fold(
        0,
        (s, t) => s + t.montant,
      );
}

  double get solde {

    return totalEntrees - totalSorties;
  }

  IconData getIcon(String categorie) {

    switch (categorie) {

      case "Salaire":
        return Icons.work;

      case "Business":
        return Icons.business_center;

      case "Education":
        return Icons.school;

      case "Transport":
        return Icons.directions_car;

      case "Restaurant":
        return Icons.restaurant;

      case "Maquis":
        return Icons.local_bar;

      case "Shopping":
        return Icons.shopping_bag;

      case "Santé":
        return Icons.local_hospital;

      case "Facture":
        return Icons.receipt;

      case "Loisir":
        return Icons.sports_esports;

      default:
        return Icons.account_balance_wallet;
    }
  }

  Color getColor(String type) {

    return type == "Entrée"
        ? Colors.green
        : Colors.red;
  }

  void supprimerTransaction(int index) {

    setState(() {

      widget.transactions.removeAt(index);
    });

    widget.onChanged();
  }

  void ajouterOuModifier({
    String type = "Entrée",
    TransactionItem? transaction,
    int? index,
  }) {

    bool modification =
        transaction != null;

    TextEditingController
        descriptionController =
        TextEditingController(
      text: transaction?.description ?? "",
    );

    TextEditingController
        montantController =
        TextEditingController(
      text: transaction != null
          ? transaction.montant
              .toStringAsFixed(0)
          : "",
    );

    List<String> categories =
        type == "Entrée"
            ? categoriesEntree
            : categoriesSortie;

    String categorie =
        transaction?.categorie ??
            categories.first;

    String moyenPaiement =
        transaction?.moyenPaiement ??
            moyensPaiement.first;

    showDialog(
      context: context,
      builder: (_) {

        return StatefulBuilder(
          builder: (context, setModalState) {

            return AlertDialog(

              title: Text(
                modification
                    ? "Modifier"
                    : "Ajouter",
              ),

              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [

                    TextField(
                      controller:
                          descriptionController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Description",
                      ),
                    ),

                    const SizedBox(
                        height: 10),

                    TextField(
                      controller:
                          montantController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Montant",
                      ),
                    ),

                    const SizedBox(
                        height: 10),

                    DropdownButtonFormField<
                        String>(
                      value: categorie,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Catégorie",
                      ),
                      items:
                          categories.map((c) {

                        return DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        );
                      }).toList(),
                      onChanged: (v) {

                        setModalState(() {
                          categorie = v!;
                        });
                      },
                    ),

                    const SizedBox(
                        height: 10),

                    DropdownButtonFormField<
                        String>(
                      value:
                          moyenPaiement,
                      decoration:
                          const InputDecoration(
                        labelText:
                            "Paiement",
                      ),
                      items:
                          moyensPaiement.map((m) {

                        return DropdownMenuItem(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (v) {

                        setModalState(() {
                          moyenPaiement =
                              v!;
                        });
                      },
                    ),
                  ],
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () {

                    Navigator.pop(
                        context);
                  },
                  child:
                      const Text("Annuler"),
                ),

                ElevatedButton(
                  onPressed: () {

                     TransactionItem t =
    TransactionItem(

  id:

      modification

          ? transaction!.id

          : DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),

  type: type,

  categorie:
      categorie,

  moyenPaiement:
      moyenPaiement,

  description:
      descriptionController
          .text,

  montant:
      double.tryParse(
            montantController
                .text,
          ) ??
          0,

  date:

      modification

          ? transaction.date

          : DateTime
              .now()
              .toString(),
);

                    setState(() {

                      if (modification) {

                        widget.transactions[
                            index!] = t;
                      } else {

                        widget.transactions
                            .insert(0, t);
                      }
                    });

                    widget.onChanged();

                    Navigator.pop(context);
                  },
                  child: Text(
                    modification
                        ? "Modifier"
                        : "Ajouter",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    List<TransactionItem>
        transactionsFiltrees =
        widget.transactions.where((t) {

      String q =
          recherche.toLowerCase();

      return t.description
              .toLowerCase()
              .contains(q) ||
          t.categorie
              .toLowerCase()
              .contains(q) ||
          t.moyenPaiement
              .toLowerCase()
              .contains(q);
    }).toList();

    return Scaffold(

      

      body: Column(
        children: [

          const SizedBox(height: 10),

          Card(
            margin:
                const EdgeInsets.all(12),
            elevation: 5,
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 12,
),
              child: Column(
                children: [
const Text(
  "SOLDE",
                
                  style: TextStyle(
  color: Colors.black54,
  fontSize: 14,
  fontWeight: FontWeight.bold,
  letterSpacing: 1,
),
                  ),

                  const SizedBox(
                      height: 10),

                  Text(
                    "${formatMontant(solde)} FCFA",
                    style:
                        const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                      height: 6),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceAround,
                    children: [

                      Column(
                        children: [

                          const Text(
                            "Entrées",
                            style:
                                TextStyle(
                              color:
                                  Colors.green,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          Text(
                            "${formatMontant(totalEntrees)} FCFA",
                          ),
                        ],
                      ),

                      Column(
                        children: [

                          const Text(
                            "Sorties",
                            style:
                                TextStyle(
                              color:
                                  Colors.red,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          Text(
                            "${formatMontant(totalSorties)} FCFA",
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: TextField(
              decoration:
                  InputDecoration(
                hintText:
                    "Rechercher...",
                prefixIcon:
                    const Icon(Icons.search),
                filled: true,
                fillColor:
                    Colors.white,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
              onChanged: (value) {

                setState(() {
                  recherche = value;
                });
              },
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [

                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed: () =>
                        ajouterOuModifier(
                      type: "Entrée",
                    ),
                    icon:
                        const Icon(Icons.add),
                    label: const Text(
                      "Ajouter entrée",
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.green,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed: () =>
                        ajouterOuModifier(
                      type: "Sortie",
                    ),
                    icon: const Icon(
                      Icons.remove,
                    ),
                    label: const Text(
                      "Ajouter sortie",
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              itemCount:
                  transactionsFiltrees
                      .length,
              itemBuilder:
                  (context, index) {

                final t =
                    transactionsFiltrees[
                        index];

                bool entree =
                    t.type == "Entrée";

                return AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 300,
                  ),
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Card(
                    color: entree
                        ? Colors.green
                            .withOpacity(
                            0.05,
                          )
                        : Colors.red
                            .withOpacity(
                            0.05,
                          ),
                    elevation: 3,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      child: Row(
                        children: [

                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                getColor(
                              t.type,
                            ).withOpacity(
                              0.15,
                            ),
                            child: Icon(
                              getIcon(
                                t.categorie,
                              ),
                              color:
                                  getColor(
                                t.type,
                              ),
                            ),
                          ),

                          const SizedBox(
                              width: 12),

                          Expanded(
  child: Column(
    crossAxisAlignment:
        CrossAxisAlignment.start,
    children: [

      Text(
        t.description,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),

      const SizedBox(height: 4),

      Text(
        "${t.categorie} • ${t.moyenPaiement}",
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 4),

      Text(
        formatDate(
          t.date,
        ),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
),
                          Column(
                            children: [

                              Text(
                                "${formatMontant(t.montant)} FCFA",
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize:
                                      18,
                                  color:
                                      getColor(
                                    t.type,
                                  ),
                                ),
                              ),

                              Row(
                                children: [

                                  IconButton(
                                    onPressed:
                                        () =>
                                            ajouterOuModifier(
                                      type:
                                          t.type,
                                      transaction:
                                          t,
                                      index:
                                          index,
                                    ),
                                    icon:
                                        const Icon(
                                      Icons.edit,
                                      color:
                                          Colors.blue,
                                    ),
                                  ),

                                  IconButton(
                                    onPressed:
                                        () =>
                                            supprimerTransaction(
                                      index,
                                    ),
                                    icon:
                                        const Icon(
                                      Icons.delete,
                                      color:
                                          Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatistiquesPage extends StatefulWidget {

  final List<TransactionItem>
      transactions;

  const StatistiquesPage({
    super.key,
    required this.transactions,
  });

  @override
  State<StatistiquesPage> createState() =>
      _StatistiquesPageState();
}

class _StatistiquesPageState
    extends State<StatistiquesPage> {

  DateTime? dateDebut;
  DateTime? dateFin;

  double totalEntrees = 0;
  double totalSorties = 0;

  Map<String, double>
      statsCategories = {};

  String categorieDominante = "";
  double montantDominant = 0;

  String formatMontant(double montant) {

    return NumberFormat(
      "#,##0",
      "fr_FR",
    ).format(montant);
  }

  Future<void> choisirDateDebut() async {

    DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {

      setState(() {
        dateDebut = picked;
      });
    }
  }

  Future<void> choisirDateFin() async {

    DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {

      setState(() {
        dateFin = picked;
      });
    }
  }

  void analyser() {

    if (dateDebut == null ||
        dateFin == null) {
      return;
    }

    totalEntrees = 0;
    totalSorties = 0;

    statsCategories.clear();

    for (var t in widget.transactions) {

      DateTime d =
          DateTime.parse(t.date);

      if (d.isAfter(
            dateDebut!.subtract(
              const Duration(days: 1),
            ),
          ) &&
          d.isBefore(
            dateFin!.add(
              const Duration(days: 1),
            ),
          )) {

        if (t.type == "Entrée") {

          totalEntrees += t.montant;
        } else {

          totalSorties += t.montant;

          statsCategories[t.categorie] =
              (statsCategories[t.categorie] ??
                      0) +
                  t.montant;
        }
      }
    }

    categorieDominante = "";
    montantDominant = 0;

    statsCategories.forEach(
      (k, v) {

        if (v > montantDominant) {

          montantDominant = v;
          categorieDominante = k;
        }
      },
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    double solde =
        totalEntrees - totalSorties;

    double ratio =
        totalEntrees > 0
            ? (totalSorties /
                    totalEntrees) *
                100
            : 0;

    List<MapEntry<String, double>>
        categoriesTriees =
        statsCategories.entries.toList()

          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    return Scaffold(

      appBar: AppBar(
        title:
            const Text("Statistiques"),
        backgroundColor:
            Colors.green,
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [

            Card(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  children: [

                    const Text(
                      "Choisir une période",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 20),

                    Row(
                      children: [

                        Expanded(
                          child:
                              ElevatedButton(
                            onPressed:
                                choisirDateDebut,
                            child: Text(
                              dateDebut ==
                                      null
                                  ? "Date début"
                                  : DateFormat(
                                      "dd/MM/yyyy",
                                    ).format(
                                      dateDebut!,
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(
                            width: 10),

                        Expanded(
                          child:
                              ElevatedButton(
                            onPressed:
                                choisirDateFin,
                            child: Text(
                              dateFin ==
                                      null
                                  ? "Date fin"
                                  : DateFormat(
                                      "dd/MM/yyyy",
                                    ).format(
                                      dateFin!,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 20),

                    ElevatedButton.icon(
                      onPressed:
                          analyser,
                      icon:
                          const Icon(
                        Icons.analytics,
                      ),
                      label:
                          const Text(
                        "Analyser",
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  children: [

                    const Text(
                      "Résumé période",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 20),

                    statLine(
                      "Entrées",
                      "${formatMontant(totalEntrees)} FCFA",
                      Colors.green,
                    ),

                    statLine(
                      "Sorties",
                      "${formatMontant(totalSorties)} FCFA",
                      Colors.red,
                    ),

                    statLine(
                      "Solde",
                      "${formatMontant(solde)} FCFA",
                      Colors.blue,
                    ),

                    statLine(
                      "Ratio dépenses",
                      "${ratio.toStringAsFixed(1)} %",
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    const Text(
                      "Catégorie dominante",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 15),

                    Text(
                      categorieDominante
                              .isEmpty
                          ? "Aucune donnée"
                          : "$categorieDominante → ${formatMontant(montantDominant)} FCFA",
                      style:
                          const TextStyle(
                        fontSize: 20,
                        color:
                            Colors.deepOrange,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    const Text(
                      "Statistiques catégories",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 20),

                    ...categoriesTriees
                        .map(
                      (e) {

                        double progression =
                            montantDominant >
                                    0
                                ? e.value /
                                    montantDominant
                                : 0;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [

                                  Text(
                                    e.key,
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          16,
                                    ),
                                  ),

                                  Text(
                                    "${formatMontant(e.value)} FCFA",
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                  height: 6),

                              LinearProgressIndicator(
                                value:
                                    progression,
                                minHeight: 8,
                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),
                                color:
                                    Colors.green,
                                backgroundColor:
                                    Colors.grey
                                        .shade300,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statLine(
    String titre,
    String valeur,
    Color couleur,
  ) {

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [

          Text(
            titre,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          Text(
            valeur,
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}
class EpargnePage extends StatelessWidget {
  final List<TransactionItem> transactions;

  const EpargnePage({
    super.key,
    required this.transactions,
  });

  double get totalEpargne {
    return transactions
        .where(
          (t) =>
              t.type == "Sortie" &&
              t.categorie == "Épargne",
        )
        .fold(
          0,
          (s, t) => s + t.montant,
        );
  }

  String formatMontant(double montant) {
    return NumberFormat(
      "#,##0",
      "fr_FR",
    ).format(montant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(25),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.savings,
                  size: 60,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Épargne totale",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "${formatMontant(totalEpargne)} FCFA",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4A017),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}