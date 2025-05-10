import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_contact_page.dart';
import 'contact_model.dart';

class ContactsListPage extends StatelessWidget {
  const ContactsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddContactPage()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('client_contacts')
            .orderBy('dateAjout', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = snapshot.data!.docs.map((doc) {
            return ClientContact.fromFirestore(doc);
          }).toList();

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                title: Text('${contact.prenom} ${contact.nom}'),
                subtitle: Text(contact.telephone),
                trailing: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _showCommunicationOptions(context, contact),
                ),
                onTap: () => _showContactDetails(context, contact),
              );
            },
          );
        },
      ),
    );
  }

  void _showContactDetails(BuildContext context, ClientContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${contact.prenom} ${contact.nom}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Téléphone: ${contact.telephone}'),
              Text('Email: ${contact.email}'),
              if (contact.entreprise != null) Text('Entreprise: ${contact.entreprise}'),
              if (contact.notes != null) Text('Notes: ${contact.notes}'),
              const SizedBox(height: 10),
              Text('Canaux: ${contact.canauxCommunication.join(', ')}'),
              Text('Consentement pub: ${contact.consentementPub ? 'Oui' : 'Non'}'),
              Text('Date ajout: ${DateFormat('dd/MM/yyyy').format(contact.dateAjout)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showCommunicationOptions(BuildContext context, ClientContact contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Envoyer un email'),
            onTap: () {
              Navigator.pop(context);
              _launchEmail(contact.email);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('Envoyer un SMS'),
            onTap: () {
              Navigator.pop(context);
              _launchSMS(contact.telephone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Appeler'),
            onTap: () {
              Navigator.pop(context);
              _launchPhoneCall(contact.telephone);
            },
          ),
        ],
      ),
    );
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchSMS(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchPhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}