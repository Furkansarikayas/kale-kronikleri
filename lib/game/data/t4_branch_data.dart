import 'tower_data.dart';

enum T4BranchPath { none, pathA, pathB }

class T4BranchDef {
  final String nameA;
  final String nameB;
  final String descA;
  final String descB;
  // Stat multipliers for each path
  final double dmgMultA;
  final double dmgMultB;
  final double rangeMultA;
  final double rangeMultB;
  final double fireRateMultA;
  final double fireRateMultB;

  const T4BranchDef({
    required this.nameA,
    required this.nameB,
    required this.descA,
    required this.descB,
    this.dmgMultA = 1.0,
    this.dmgMultB = 1.0,
    this.rangeMultA = 1.0,
    this.rangeMultB = 1.0,
    this.fireRateMultA = 1.0,
    this.fireRateMultB = 1.0,
  });
}

class T4BranchData {
  T4BranchData._();

  static const Map<TowerType, T4BranchDef> branches = {
    TowerType.arrow: T4BranchDef(
      nameA: 'Fırtına Yağmuru',
      nameB: 'Keskin Nişancı',
      descA: 'Çoklu hedef, düşük hasar',
      descB: 'Tek hedef, 3x hasar',
      dmgMultA: 0.5, fireRateMultA: 0.4, // multi-target via lower cooldown
      dmgMultB: 3.0, fireRateMultB: 1.5, // single target, slow but devastating
    ),
    TowerType.ice: T4BranchDef(
      nameA: 'Mutlak Sıfır',
      nameB: 'Buzul Alanı',
      descA: 'Tam dondurma, kısa menzil',
      descB: 'Geniş alan yavaşlatma',
      dmgMultA: 1.2, rangeMultA: 0.7,
      dmgMultB: 0.8, rangeMultB: 1.8,
    ),
    TowerType.fire: T4BranchDef(
      nameA: 'Cehennem Ateşi',
      nameB: 'Anka Kuşu',
      descA: 'Güçlü yanma hasarı',
      descB: 'Öldürünce kaleyi iyileştirir',
      dmgMultA: 1.8, fireRateMultA: 1.2,
      dmgMultB: 1.2,
    ),
    TowerType.lightning: T4BranchDef(
      nameA: 'Tanrı Öfkesi',
      nameB: 'EMP Darbesi',
      descA: '4 hedefe zincir hasar',
      descB: 'Düşman yeteneklerini devre dışı bırakır',
      dmgMultA: 1.5, rangeMultA: 1.2,
      dmgMultB: 1.0, rangeMultB: 1.3,
    ),
    TowerType.poison: T4BranchDef(
      nameA: 'Nekroz',
      nameB: 'Veba Yayılımı',
      descA: 'Güçlü zehir, yüksek hasar',
      descB: 'Öldürünce zehiri yakar',
      dmgMultA: 1.8,
      dmgMultB: 1.3,
    ),
    TowerType.cannon: T4BranchDef(
      nameA: 'Meteor',
      nameB: 'Kuşatma Topu',
      descA: 'Dev patlama alanı',
      descB: 'Boss düşmanlara 2x hasar',
      dmgMultA: 1.3, rangeMultA: 1.5,
      dmgMultB: 2.0,
    ),
    TowerType.spikeWall: T4BranchDef(
      nameA: 'Kara Orman',
      nameB: 'Dikenli Labirent',
      descA: 'Geniş hasar alanı',
      descB: 'Güçlü yavaşlatma efekti',
      dmgMultA: 1.5, rangeMultA: 1.5,
      dmgMultB: 1.2,
    ),
    TowerType.support: T4BranchDef(
      nameA: 'Savaş Bayrağı',
      nameB: 'İyileştirme Aurası',
      descA: 'Komşu kulelere +%25 hasar',
      descB: 'Kaleyi dalgalar arası iyileştirir',
      dmgMultA: 1.0,
      dmgMultB: 1.0,
    ),
    TowerType.water: T4BranchDef(
      nameA: 'Girdap',
      nameB: 'Tsunami',
      descA: 'Düşmanları yavaşlatır + hasar',
      descB: 'Büyük alan ıslatma',
      dmgMultA: 1.5,
      dmgMultB: 0.8, rangeMultB: 2.0,
    ),
    TowerType.wizard: T4BranchDef(
      nameA: 'Arş Büyücü',
      nameB: 'Büyüleyici',
      descA: '5 hedefe zincir hasar',
      descB: 'Komşu kulelere +%20 hasar',
      dmgMultA: 1.5,
      dmgMultB: 1.0,
    ),
    TowerType.dark: T4BranchDef(
      nameA: 'Uçurum',
      nameB: 'Gölge Avcı',
      descA: '%100 lanet, güçlü zırh kırma',
      descB: 'Görünmez kule, sürpriz hasar',
      dmgMultA: 1.3,
      dmgMultB: 2.0, fireRateMultB: 1.5,
    ),
    TowerType.holy: T4BranchDef(
      nameA: 'Işık Kalesi',
      nameB: 'İlahi Kalkan',
      descA: 'Güçlü kutsal alan hasarı',
      descB: 'Her 10 saniyede kaleyi korur',
      dmgMultA: 1.8, rangeMultA: 1.3,
      dmgMultB: 1.0,
    ),
  };

  static T4BranchDef getBranch(TowerType type) => branches[type]!;
}
