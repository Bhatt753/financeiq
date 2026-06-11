// ── Merchant → Category map ────────────────────────────────────────────────
// Longer / more-specific keys are matched preferentially by getMerchantCategory.
// Keep multi-word entries (e.g. "uber eats") before their root (e.g. "uber")
// so the longest match wins.

const Map<String, String> merchantDatabase = {
  // ── Food & Groceries ──────────────────────────────────────────────────────
  'cafe coffee day': 'Food & Groceries',
  'more supermarket': 'Food & Groceries',
  'more market': 'Food & Groceries',
  'reliance fresh': 'Food & Groceries',
  'nature basket': 'Food & Groceries',
  'mother dairy': 'Food & Groceries',
  'rebel foods': 'Food & Groceries',
  'uber eats': 'Food & Groceries',
  'burger king': 'Food & Groceries',
  'pizza hut': 'Food & Groceries',
  'swiggy': 'Food & Groceries',
  'zomato': 'Food & Groceries',
  'blinkit': 'Food & Groceries',
  'zepto': 'Food & Groceries',
  'bigbasket': 'Food & Groceries',
  'grofers': 'Food & Groceries',
  'dunzo': 'Food & Groceries',
  'magicpin': 'Food & Groceries',
  'eatsure': 'Food & Groceries',
  'freshmenu': 'Food & Groceries',
  'box8': 'Food & Groceries',
  'faasos': 'Food & Groceries',
  'dominos': 'Food & Groceries',
  'domino': 'Food & Groceries',
  'mcdonalds': 'Food & Groceries',
  'mcdonald': 'Food & Groceries',
  'kfc': 'Food & Groceries',
  'subway': 'Food & Groceries',
  'starbucks': 'Food & Groceries',
  'haldirams': 'Food & Groceries',
  'haldiram': 'Food & Groceries',
  'ccd': 'Food & Groceries',
  'amul': 'Food & Groceries',
  'dmart': 'Food & Groceries',
  'spencer': 'Food & Groceries',
  'foodpanda': 'Food & Groceries',

  // ── Transport ────────────────────────────────────────────────────────────
  'makemytrip trains': 'Transport',
  'hp petrol': 'Transport',
  'indian oil': 'Transport',
  'bharat petroleum': 'Transport',
  'rapido': 'Transport',
  'redbus': 'Transport',
  'abhibus': 'Transport',
  'savaari': 'Transport',
  'fastag': 'Transport',
  'jugnoo': 'Transport',
  'irctc': 'Transport',
  'bmtc': 'Transport',
  'meru': 'Transport',
  'uber': 'Transport',
  'ola': 'Transport',
  'dtc': 'Transport',
  'metro': 'Transport',
  'best': 'Transport',
  'shell': 'Transport',
  'petrol': 'Transport',
  'toll': 'Transport',
  'fuel': 'Transport',

  // ── Shopping ─────────────────────────────────────────────────────────────
  'reliance digital': 'Shopping',
  'vijay sales': 'Shopping',
  'max fashion': 'Shopping',
  'apple store': 'Shopping',
  'tata cliq': 'Shopping',
  'paytm mall': 'Shopping',
  'snapdeal': 'Shopping',
  'flipkart': 'Shopping',
  'meesho': 'Shopping',
  'myntra': 'Shopping',
  'amazon': 'Shopping',
  'ajio': 'Shopping',
  'nykaa': 'Shopping',
  'purplle': 'Shopping',
  'shopsy': 'Shopping',
  'glowroad': 'Shopping',
  'limeroad': 'Shopping',
  'jabong': 'Shopping',
  'koovs': 'Shopping',
  'lifestyle': 'Shopping',
  'pantaloons': 'Shopping',
  'westside': 'Shopping',
  'zara': 'Shopping',
  'uniqlo': 'Shopping',
  'decathlon': 'Shopping',
  'croma': 'Shopping',
  'h&m': 'Shopping',

  // ── Entertainment ─────────────────────────────────────────────────────────
  'amazon prime': 'Entertainment',
  'youtube premium': 'Entertainment',
  'carnival cinemas': 'Entertainment',
  'apple music': 'Entertainment',
  'play games': 'Entertainment',
  'sony liv': 'Entertainment',
  'sonyliv': 'Entertainment',
  'bookmyshow': 'Entertainment',
  'jiocinema': 'Entertainment',
  'jiosaavn': 'Entertainment',
  'cinepolis': 'Entertainment',
  'hotstar': 'Entertainment',
  'netflix': 'Entertainment',
  'disney': 'Entertainment',
  'mxplayer': 'Entertainment',
  'hungama': 'Entertainment',
  'spotify': 'Entertainment',
  'gaana': 'Entertainment',
  'wynk': 'Entertainment',
  'voot': 'Entertainment',
  'zee5': 'Entertainment',
  'inox': 'Entertainment',
  'pvr': 'Entertainment',

  // ── Healthcare ────────────────────────────────────────────────────────────
  'apollo pharmacy': 'Healthcare',
  'hdfc ergo health': 'Healthcare',
  'manipal hospital': 'Healthcare',
  'dr lal pathlabs': 'Healthcare',
  'columbia asia': 'Healthcare',
  'max hospital': 'Healthcare',
  'star health': 'Healthcare',
  'niva bupa': 'Healthcare',
  'tata 1mg': 'Healthcare',
  'cloudnine': 'Healthcare',
  'healthians': 'Healthcare',
  'pharmeasy': 'Healthcare',
  'thyrocare': 'Healthcare',
  'netmeds': 'Healthcare',
  'medplus': 'Healthcare',
  'practo': 'Healthcare',
  'lybrate': 'Healthcare',
  'fortis': 'Healthcare',
  'apollo': 'Healthcare',
  'aiims': 'Healthcare',
  'mfine': 'Healthcare',
  '1mg': 'Healthcare',

  // ── Education ─────────────────────────────────────────────────────────────
  'whitehat jr': 'Education',
  'great learning': 'Education',
  'linkedin learning': 'Education',
  'khan academy': 'Education',
  'unacademy': 'Education',
  'simplilearn': 'Education',
  'skillshare': 'Education',
  'coursera': 'Education',
  'vedantu': 'Education',
  'upgrad': 'Education',
  'duolingo': 'Education',
  'embibe': 'Education',
  'toppr': 'Education',
  'chegg': 'Education',
  'udemy': 'Education',
  'byju': 'Education',
  'edx': 'Education',

  // ── Utilities ─────────────────────────────────────────────────────────────
  'adani electricity': 'Utilities',
  'indraprastha gas': 'Utilities',
  'mahanagar gas': 'Utilities',
  'gas authority': 'Utilities',
  'delhi jal board': 'Utilities',
  'act fibernet': 'Utilities',
  'reliance jio': 'Utilities',
  'tata power': 'Utilities',
  'tata sky': 'Utilities',
  'sun direct': 'Utilities',
  'vodafone': 'Utilities',
  'vi mobile': 'Utilities',
  'hathway': 'Utilities',
  'bescom': 'Utilities',
  'airtel': 'Utilities',
  'dish tv': 'Utilities',
  'bwssb': 'Utilities',
  'bsnl': 'Utilities',
  'mseb': 'Utilities',
  'd2h': 'Utilities',
  'jio': 'Utilities',
  'vi': 'Utilities',

  // ── Travel ───────────────────────────────────────────────────────────────
  'makemytrip': 'Travel',
  'easemytrip': 'Travel',
  'booking.com': 'Travel',
  'akasa air': 'Travel',
  'air india': 'Travel',
  'air asia': 'Travel',
  'go first': 'Travel',
  'fabhotels': 'Travel',
  'goibibo': 'Travel',
  'cleartrip': 'Travel',
  'spicejet': 'Travel',
  'vistara': 'Travel',
  'airbnb': 'Travel',
  'treebo': 'Travel',
  'zostel': 'Travel',
  'indigo': 'Travel',
  'yatra': 'Travel',
  'ixigo': 'Travel',
  'agoda': 'Travel',
  'oyo': 'Travel',

  // ── Investment ────────────────────────────────────────────────────────────
  'sbi mutual fund': 'Investment',
  'hdfc mutual fund': 'Investment',
  'hdfc securities': 'Investment',
  'coin by zerodha': 'Investment',
  'kotak securities': 'Investment',
  'angel broking': 'Investment',
  'motilal oswal': 'Investment',
  'icici direct': 'Investment',
  'nippon india': 'Investment',
  'paytm money': 'Investment',
  'zerodha': 'Investment',
  'etmoney': 'Investment',
  'upstox': 'Investment',
  '5paisa': 'Investment',
  'groww': 'Investment',
};

// ── Category metadata ──────────────────────────────────────────────────────

const Map<String, String> categoryIcons = {
  'Food & Groceries': '🍕',
  'Transport': '🚗',
  'Shopping': '🛍️',
  'Entertainment': '🎬',
  'Healthcare': '💊',
  'Education': '📚',
  'Utilities': '💡',
  'Travel': '✈️',
  'Investment': '📈',
  'Rent/Housing': '🏠',
  'Other': '💰',
};

const Map<String, String> categoryColors = {
  'Food & Groceries': '#60a5fa',
  'Transport': '#fbbf24',
  'Shopping': '#f87171',
  'Entertainment': '#a78bfa',
  'Healthcare': '#34d399',
  'Education': '#fb923c',
  'Utilities': '#e879f9',
  'Travel': '#22d3ee',
  'Investment': '#4ade80',
  'Rent/Housing': '#94a3b8',
  'Other': '#64748b',
};

// ── Lookup functions ───────────────────────────────────────────────────────

String? getMerchantCategory(String merchantName) {
  final lower = merchantName.toLowerCase();
  String? bestCategory;
  int bestLength = 0;

  merchantDatabase.forEach((key, category) {
    if (lower.contains(key) && key.length > bestLength) {
      bestCategory = category;
      bestLength = key.length;
    }
  });

  return bestCategory;
}

String getCategoryWithFallback(String? merchantName, String smsBody) {
  if (merchantName != null && merchantName.isNotEmpty) {
    final cat = getMerchantCategory(merchantName);
    if (cat != null) return cat;
  }
  final catFromBody = getMerchantCategory(smsBody);
  if (catFromBody != null) return catFromBody;
  return 'Other';
}
