public class LineItemNodeWrapper {

    public Map<String, Object> tags { get; set; }
    public List<Object> dataPath { get; set; }
    public List<Object> salesPath { get; set; }
    public Boolean deleted { get; set; }

    public String productCode { get; set; }
    public String sellingModelType { get; set; }

    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    public LineItemNodeWrapper(Object node) {

        Map<String, Object> obj = (Map<String, Object>) node;

        // Full dataPath from context
        this.dataPath = (List<Object>) obj.get('dataPath');

        // CRITICAL: salesPath = ONLY last 2 levels
        if (dataPath != null && dataPath.size() >= 3) {
            this.salesPath = new List<Object>{
                dataPath.get(1),
                dataPath.get(2)
            };
        }

        // Tags
        this.tags = (Map<String, Object>) obj.get('tagValue');

        // Deleted flag
        this.deleted = false;
        if (tags != null && tags.containsKey('IsDeleted')) {
            Object del =
                ((Map<String, Object>) tags.get('IsDeleted'))
                .get('tagValue');

            if (del != null) {
                this.deleted = Boolean.valueOf(String.valueOf(del));
            }
        }

        // Product Code
        this.productCode = getString('ProductCode');

        // Selling Model
        this.sellingModelType = getString('SellingModelType');
    }

    // =========================================================
    // VALIDATION
    // =========================================================
    public Boolean isValid() {
        return dataPath != null
            && dataPath.size() >= 3
            && salesPath != null
            && salesPath.size() == 2;
    }

    // =========================================================
    // GENERIC GETTERS
    // =========================================================
    private String getString(String key) {
        try {
            if (tags != null && tags.containsKey(key)) {
                Object val =
                    ((Map<String, Object>) tags.get(key))
                    .get('tagValue');

                return val != null ? String.valueOf(val) : null;
            }
        } catch (Exception e) {}
        return null;
    }

    // =========================================================
    // OPTIONAL: TERM CHECK (NOT USED NOW)
    // =========================================================
    public Boolean isTermBased() {
        return sellingModelType != null
            && sellingModelType.toLowerCase().contains('term');
    }
}