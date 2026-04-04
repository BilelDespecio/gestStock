import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../vendeur/constants.dart';
import 'add_contact_page.dart';
import 'contact_model.dart';

class ContactsListPage extends StatefulWidget {
  const ContactsListPage({super.key});

  @override
  State<ContactsListPage> createState() => _ContactsListPageState();
}

class _ContactsListPageState extends State<ContactsListPage> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Mes Contacts Clients', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        elevation: 1,
        actions: [
          IconButton(
            icon:  Icon(Icons.person_add_alt_1, color: AppColors.accentColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddContactPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Chercher un nom ou un numéro...',
                  hintStyle:  TextStyle(color: AppColors.secondaryTextColor),
                  prefixIcon:  Icon(Icons.search, color: AppColors.accentColor),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      }) 
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('client_contacts')
                  .orderBy('dateAjout', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}', style:  TextStyle(color: AppColors.criticalColor)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return  Center(child: CircularProgressIndicator(color: AppColors.accentColor));
                }

                final allContacts = snapshot.data!.docs.map((doc) {
                  return ClientContact.fromFirestore(doc);
                }).toList();

                final filteredContacts = allContacts.where((contact) {
                  final searchLower = _searchQuery.toLowerCase();
                  return contact.nom.toLowerCase().contains(searchLower) ||
                         contact.prenom.toLowerCase().contains(searchLower) ||
                         contact.telephone.contains(searchLower);
                }).toList();

                if (filteredContacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 64, color: AppColors.secondaryTextColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Aucun contact enregistré' : 'Aucun résultat trouvé',
                          style:  TextStyle(color: AppColors.secondaryTextColor, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.accentColor.withOpacity(0.1),
                          child: Text(
                            contact.initiales.toUpperCase(),
                            style:  TextStyle(color: AppColors.accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(contact.nomComplet, style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
                        subtitle: Text(contact.telephone, style:  TextStyle(color: AppColors.secondaryTextColor)),
                        trailing: IconButton(
                          icon:  Icon(Icons.message_outlined, color: AppColors.accentColor),
                          onPressed: () => _showCommunicationOptions(context, contact),
                        ),
                        onTap: () => _showContactDetails(context, contact),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDetails(BuildContext context, ClientContact contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration:  BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.accentColor.withOpacity(0.1),
                  child: Text(contact.initiales.toUpperCase(), style:  TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accentColor)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.nomComplet, style:  TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
                      if (contact.entreprise != null && contact.entreprise!.isNotEmpty)
                        Text(contact.entreprise!, style:  TextStyle(color: AppColors.accentColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildDetailRow(Icons.phone_outlined, 'Téléphone', contact.telephone),
            _buildDetailRow(Icons.email_outlined, 'Email', contact.email),
            if (contact.notes != null && contact.notes!.isNotEmpty)
              _buildDetailRow(Icons.notes, 'Notes', contact.notes!),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text('Canaux préférés', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryTextColor)),
                Text(DateFormat('dd MMM yyyy').format(contact.dateAjout), style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: contact.canauxCommunication.map((c) => Chip(
                label: Text(c, style: const TextStyle(fontSize: 10)),
                backgroundColor: AppColors.backgroundColor,
                side: BorderSide.none,
                labelStyle:  TextStyle(color: AppColors.accentColor),
              )).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchPhoneCall(contact.telephone),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text('Appeler', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.priceColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCommunicationOptions(context, contact),
                    icon:  Icon(Icons.chat_bubble_outline, color: AppColors.accentColor),
                    label:  Text('Message', style: TextStyle(color: AppColors.accentColor)),
                    style: OutlinedButton.styleFrom(side:  BorderSide(color: AppColors.accentColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryTextColor),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
              Text(value, style:  TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryTextColor)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommunicationOptions(BuildContext context, ClientContact contact) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Contacter ce client via', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading:  Icon(Icons.email, color: AppColors.accentColor),
            title: const Text('Envoyer un email'),
            onTap: () { Navigator.pop(context); _launchEmail(contact.email); },
          ),
          ListTile(
            leading:  Icon(Icons.sms, color: AppColors.priceColor),
            title: const Text('Envoyer un SMS'),
            onTap: () { Navigator.pop(context); _launchSMS(contact.telephone); },
          ),
          ListTile(
            leading:  Icon(Icons.phone, color: AppColors.accentColor),
            title: const Text('Appeler'),
            onTap: () { Navigator.pop(context); _launchPhoneCall(contact.telephone); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _launchSMS(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _launchPhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}