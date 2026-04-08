class MetaNode {
  final String name;
  final String description;
  final int cost;
  final int runGate;
  const MetaNode({required this.name, required this.description, required this.cost, this.runGate = 0});

  bool canUnlock({required int spirit, required int currentLevel, required int totalRuns}) {
    if (spirit < cost) return false;
    if (runGate > 0 && totalRuns < runGate) return false;
    return true;
  }
}

class MetaTreeDef {
  final String id;
  final String name;
  final String subtitle;
  final List<MetaNode> nodes;
  const MetaTreeDef({required this.id, required this.name, required this.subtitle, required this.nodes});
}

class MetaTree {
  MetaTree._();

  /// First 3 meta unlocks across all trees cost 50% less.
  static int effectiveCost(int baseCost, int totalUnlocks) {
    if (totalUnlocks < 3) return (baseCost * 0.5).round();
    return baseCost;
  }

  static const List<MetaTreeDef> trees = [
    MetaTreeDef(id: 'savas', name: 'Savaş Ağacı', subtitle: 'Kule gücü ve savaş bonusları', nodes: [
      MetaNode(name: 'Kule Hafızası', description: 'Her runda +1 ekstra kule slotu', cost: 15),
      MetaNode(name: 'Demir İrade', description: 'Başlangıç canı %25 artar', cost: 25),
      MetaNode(name: 'Usta Komutan', description: 'Yükseltme maliyeti %20 azalır', cost: 40),
      MetaNode(name: 'Savaş Çığlığı', description: 'İlk 3 dalga %30 hasar bonus', cost: 50),
      MetaNode(name: 'Kale Muhafızı', description: 'Duvar canı 2×', cost: 65),
      MetaNode(name: 'Son Nefes', description: 'Can 1\'e düşünce 5sn yenilmezlik', cost: 80),
      MetaNode(name: 'Çelik Yumruk', description: 'Tüm fiziksel hasar %15 artar', cost: 100),
    ]),
    MetaTreeDef(id: 'kesif', name: 'Keşif Ağacı', subtitle: 'Bilgi avantajı ve keşif bonusları', nodes: [
      MetaNode(name: 'Şifre Çözücü', description: 'Tüm kuleler dalga 1\'den açık', cost: 15),
      MetaNode(name: 'Sinerji Arşivi', description: 'Keşfedilen sinerjiler haritada gösterilir', cost: 25),
      MetaNode(name: 'Düşman Kütüphanesi', description: 'Zayıflıklar baştan görünür', cost: 40),
      MetaNode(name: 'Hazine Avcısı', description: 'Dalga arası %15 bonus altın odası', cost: 50),
      MetaNode(name: 'Bilge Göz', description: 'Eser kalitesi yükselir', cost: 65),
      MetaNode(name: 'Harita Okuyucu', description: 'Sonraki 2 dalga önizleme', cost: 80),
      MetaNode(name: 'Arkeolog', description: 'Antik eser bulma şansı', cost: 100),
    ]),
    MetaTreeDef(id: 'kale', name: 'Kale Ağacı', subtitle: 'Savunma, iyileşme ve ekonomi', nodes: [
      MetaNode(name: 'Taş Duvarlar', description: 'Hasar emme +%30', cost: 15),
      MetaNode(name: 'Hazine Odaları', description: 'Her dalgada +8 bonus altın', cost: 25),
      MetaNode(name: 'Onarım Loncası', description: 'Dalgalar arası %15 can yenile', cost: 40),
      MetaNode(name: 'Çift Sur', description: 'İkinci hasar katmanı', cost: 50),
      MetaNode(name: 'Vergi Toplayıcı', description: 'Boss öldürme 2× altın', cost: 65),
      MetaNode(name: 'Kale Ruhu', description: 'Hasar alan kuleler %10 güçlenir', cost: 80),
      MetaNode(name: 'Antik Büyü', description: 'Kale çevresinde sürekli alan hasarı', cost: 100),
    ]),
    MetaTreeDef(id: 'efsane', name: 'Efsane Ağacı', subtitle: 'Güçlü yetenekler, çok koşu gerektirir', nodes: [
      MetaNode(name: 'Ejderha Ruhu', description: 'Ejderha efekti açılır', cost: 50, runGate: 10),
      MetaNode(name: 'Zaman Büküm', description: 'Dalga hızı ayarı', cost: 75, runGate: 25),
      MetaNode(name: 'Karanlık Antlaşma', description: 'Lanet sinerji bonusu', cost: 100, runGate: 40),
      MetaNode(name: 'Işık Şampiyonu', description: 'Kutsal sinerji bonusu', cost: 125, runGate: 60),
      MetaNode(name: 'Kader Yazıcı', description: 'Eser seçimi 3\'e çıkar', cost: 150, runGate: 80),
      MetaNode(name: 'Tanrıların Gazabı', description: 'Ultimate sinerji açılır', cost: 175, runGate: 100),
      MetaNode(name: 'Ebedi Kale', description: 'Sonsuz mod açılır', cost: 200, runGate: 150),
    ]),
  ];
}
