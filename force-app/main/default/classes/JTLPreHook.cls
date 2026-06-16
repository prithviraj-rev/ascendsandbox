global class JTLPreHook implements RevSignaling.SignalingApexProcessor {

    public RevSignaling.TransactionResponse execute(
        RevSignaling.TransactionRequest request
    ) {
        RevSignaling.TransactionResponse response =
            new RevSignaling.TransactionResponse();

        try {

            String contextId = request.ctxInstanceId;

            if (String.isBlank(contextId)) {
                return success(response, 'No contextId — skipping');
            }

            Context.IndustriesContext ctx =
                new Context.IndustriesContext();

            // Get line items first
            List<Object> items = queryLineItems(contextId, ctx);
            System.debug('==total items in context== ' + items.size());

            // Count active (non-deleted) lines BEFORE doing anything
            Integer activeCount = countActiveLines(items);
            System.debug('==active lines count== ' + activeCount);

            if (activeCount == 0) {
                return success(response, 'No active lines — skipping date population');
            }

            // Build transaction context
            TransactionContext tc = build(contextId, ctx);

            System.debug('==tc.quoteStartDate== ' + tc.quoteStartDate);
            System.debug('==tc.contractTerm==   ' + tc.contractTerm);

            if (String.isBlank(tc.quoteStartDate)) {
                return success(response, 'Start Date blank — skipping');
            }

            if (tc.contractTerm == null || tc.contractTerm <= 0) {
                return success(response, 'Contract Term blank — skipping');
            }

            Date startDate = Date.valueOf(tc.quoteStartDate);
            Date endDate   = startDate.addMonths(tc.contractTerm).addDays(-1);

            System.debug('==startDate== ' + startDate);
            System.debug('==endDate==   ' + endDate);

            // Get active line IDs from SOQL
            Set<String> activeLineIds = getActiveQuoteLineIds(tc.quoteId);
            System.debug('==activeLineIds count== ' + activeLineIds.size());

            // Build updates
            List<Map<String, Object>> updates =
                buildLineUpdates(items, startDate, endDate, activeLineIds);

            System.debug('==updates count== ' + updates.size());

            if (updates.isEmpty()) {
                return success(response, 'No lines to update');
            }

            return pushUpdates(ctx, contextId, updates, response);
            
            

        } catch (Exception e) {
            System.debug('==JTLPreHook EXCEPTION== ' + e.getMessage());
            System.debug('==JTLPreHook STACK==     ' + e.getStackTraceString());
            return success(response, 'Hook error — skipped: ' + e.getMessage());
        }
    }

    // =========================================================
    // COUNT ACTIVE (NON-DELETED) LINES
    // =========================================================
    private static Integer countActiveLines(List<Object> items) {
        Integer count = 0;
        for (Object obj : items) {
            try {
                Map<String, Object> node = (Map<String, Object>) obj;

                Object rawDel = node.get('deleted');
                if (rawDel != null && Boolean.valueOf(String.valueOf(rawDel))) continue;

                Object rawDel2 = node.get('isDeleted');
                if (rawDel2 != null && Boolean.valueOf(String.valueOf(rawDel2))) continue;

                Map<String, Object> tv = (Map<String, Object>) node.get('tagValue');
                if (tv != null) {
                    if (isTagTrue(tv, 'IsDeleted')) continue;
                    if (isTagTrue(tv, 'Deleted'))   continue;
                }

                count++;
            } catch (Exception e) {}
        }
        return count;
    }

    // =========================================================
    // BUILD TRANSACTION CONTEXT
    // =========================================================
    private static TransactionContext build(
        String contextId,
        Context.IndustriesContext ctx
    ) {
        TransactionContext tc = new TransactionContext();

        Map<String, Object> res = ctx.queryTags(new Map<String, Object>{
            'contextId' => contextId,
            'tags'      => new List<String>{ 'SalesTransaction' }
        });

        Map<String, Object> queryResult =
            (Map<String, Object>) res.get('queryResult');

        if (queryResult == null) return tc;

        List<Object> nodes =
            (List<Object>) queryResult.get('SalesTransaction');

        if (nodes == null || nodes.isEmpty()) return tc;

        Map<String, Object> tags =
            (Map<String, Object>)
            ((Map<String, Object>) nodes.get(0)).get('tagValue');

        if (tags == null) return tc;

        // START DATE
        tc.quoteStartDate = extractTagDate(tags, 'StartDate');

        // QUOTE ID — scan all tags for value starting with 0Q0
        for (String key : tags.keySet()) {
            try {
                Object wrapper = tags.get(key);
                if (wrapper instanceof Map<String, Object>) {
                    Object val =
                        ((Map<String, Object>) wrapper).get('tagValue');
                    if (val != null) {
                        String strVal = String.valueOf(val).trim();
                        if (strVal.startsWith('0Q0') && strVal.length() >= 15) {
                            tc.quoteId = strVal;
                            break;
                        }
                    }
                }
            } catch (Exception e) {}
        }

        // CONTRACT TERM via SOQL
        if (String.isNotBlank(tc.quoteId)) {
            try {
                Quote q = [
                    SELECT Contract_Term_Months__c
                    FROM   Quote
                    WHERE  Id = :tc.quoteId
                    LIMIT  1
                ];
                if (q.Contract_Term_Months__c != null) {
                    tc.contractTerm =
                        Integer.valueOf(q.Contract_Term_Months__c);
                }
            } catch (Exception e) {
                System.debug('==SOQL error== ' + e.getMessage());
            }
        }

        return tc;
    }

    // =========================================================
    // GET ACTIVE QUOTE LINE IDS FROM SOQL
    // =========================================================
    private static Set<String> getActiveQuoteLineIds(String quoteId) {
        Set<String> activeIds = new Set<String>();
        if (String.isBlank(quoteId)) return activeIds;
        try {
            for (QuoteLineItem qli : [
                SELECT Id
                FROM   QuoteLineItem
                WHERE  QuoteId = :quoteId
            ]) {
                activeIds.add(qli.Id);
            }
        } catch (Exception e) {
            System.debug('==getActiveQuoteLineIds error== ' + e.getMessage());
        }
        return activeIds;
    }

    // =========================================================
    // QUERY LINE ITEMS
    // =========================================================
    private static List<Object> queryLineItems(
        String contextId,
        Context.IndustriesContext ctx
    ) {
        Map<String, Object> res = ctx.queryTags(new Map<String, Object>{
            'contextId' => contextId,
            'tags'      => new List<String>{ 'SalesTransactionItem' }
        });

        List<Object> items = (List<Object>)
            ((Map<String, Object>) res.get('queryResult'))
            .get('SalesTransactionItem');

        return items == null ? new List<Object>() : items;
    }

    // =========================================================
    // BUILD UPDATES
    // =========================================================
    private static List<Map<String, Object>> buildLineUpdates(
        List<Object> items,
        Date startDate,
        Date endDate,
        Set<String> activeLineIds
    ) {
        List<Map<String, Object>> updates =
            new List<Map<String, Object>>();

        for (Integer i = 0; i < items.size(); i++) {

            LineItemNodeWrapper li =
                new LineItemNodeWrapper(items.get(i));

            if (!li.isValid() || li.deleted) {
                System.debug('==item[' + i + '] SKIPPED wrapper==');
                continue;
            }

            // Skip if not in active SOQL set (deleted lines)
            if (!activeLineIds.isEmpty()) {
                String lineItemId = String.valueOf(li.dataPath.get(2));
                if (!activeLineIds.contains(lineItemId)) {
                    System.debug('==item[' + i + '] SKIPPED not active: ' + lineItemId);
                    continue;
                }
            }

            // ✅ Read selling model type — check wrapper value first,
            // then fall back to scanning all tag keys directly
            // This handles cases where tag key name differs per org
            String sellingModel = li.sellingModelType;

            if (String.isBlank(sellingModel)) {
                sellingModel = scanSellingModelFromTags(li.tags);
            }

            System.debug('==item[' + i + '] sellingModel== ' + sellingModel);

            // ✅ Skip One Time entirely — no StartDate, no EndDate
            if (isOneTimeSelling(sellingModel)) {
                System.debug('==item[' + i + '] SKIPPED One Time==');
                continue;
            }

            // All other selling models get both dates
            List<List<Object>> attributes = new List<List<Object>>{
                new List<Object>{ 'StartDate', 'EffectiveFrom', startDate },
                new List<Object>{ 'EndDate',   'EffectiveTo',   endDate   }
            };

            updates.add(buildNodeUpdate(li.salesPath, attributes));
        }

        return updates;
    }

    // =========================================================
    // SCAN ALL TAGS FOR SELLING MODEL VALUE
    // Fallback when LineItemNodeWrapper doesn't find SellingModelType
    // Scans every tag key whose name contains 'selling' or 'model'
    // =========================================================
    private static String scanSellingModelFromTags(
        Map<String, Object> tags
    ) {
        if (tags == null) return null;

        for (String key : tags.keySet()) {
            String keyLower = key.toLowerCase();
            if (keyLower.contains('selling') || keyLower.contains('sellingmodel')) {
                try {
                    Object val =
                        ((Map<String, Object>) tags.get(key)).get('tagValue');
                    if (val != null) {
                        String strVal = String.valueOf(val).trim();
                        System.debug('==scanSellingModel key=' + key + ' val=' + strVal);
                        return strVal;
                    }
                } catch (Exception e) {}
            }
        }

        return null;
    }

    // =========================================================
    // CHECK ONE TIME SELLING MODEL
    // Handles: "One Time", "OneTime", "One_Time", "onetime" etc.
    // =========================================================
    private static Boolean isOneTimeSelling(String sellingModelType) {
        if (String.isBlank(sellingModelType)) return false;
        String normalized = sellingModelType
            .toLowerCase()
            .replace(' ', '')
            .replace('_', '')
            .replace('-', '');
        return normalized == 'onetime';
    }

    // =========================================================
    // BUILD NODE UPDATE
    // =========================================================
    private static Map<String, Object> buildNodeUpdate(
        List<Object> dataPath,
        List<List<Object>> attributes
    ) {
        List<Object> attrs = new List<Object>();
        for (List<Object> pair : attributes) {
            attrs.add(new Map<String, Object>{
                'attributeName'  => pair[0],
                'attributeTag'   => pair[1],
                'attributeValue' => pair[2]
            });
        }
        return new Map<String, Object>{
            'nodePath'   => new Map<String, Object>{ 'dataPath' => dataPath },
            'attributes' => attrs
        };
    }

    // =========================================================
    // PUSH UPDATES
    // =========================================================
    private static RevSignaling.TransactionResponse pushUpdates(
        Context.IndustriesContext ctx,
        String contextId,
        List<Map<String, Object>> updates,
        RevSignaling.TransactionResponse response
    ) {
        try {
            ctx.updateContextAttributes(new Map<String, Object>{
                'contextId'             => contextId,
                'nodePathAndAttributes' => updates
            });
            response.status  = RevSignaling.TransactionStatus.SUCCESS;
            response.message = 'Dates populated successfully';
        } catch (Exception e) {
            System.debug('==pushUpdates ERROR== ' + e.getMessage());
            System.debug('==pushUpdates STACK== ' + e.getStackTraceString());
            response.status  = RevSignaling.TransactionStatus.SUCCESS;
            response.message = 'Date update skipped: ' + e.getMessage();
        }
        return response;
    }

    // =========================================================
    // HELPERS
    // =========================================================
    private static Boolean isTagTrue(
        Map<String, Object> tagValue,
        String key
    ) {
        if (!tagValue.containsKey(key)) return false;
        try {
            Object val =
                ((Map<String, Object>) tagValue.get(key)).get('tagValue');
            return val != null && Boolean.valueOf(String.valueOf(val));
        } catch (Exception e) {}
        return false;
    }

   /* private static String extractTagDate(
        Map<String, Object> tags,
        String key
    ) {
        if (tags == null || !tags.containsKey(key)) return null;
        try {
            Object val =
                ((Map<String, Object>) tags.get(key)).get('tagValue');
            if (val == null) return null;
            if (val instanceof Datetime) {
                return String.valueOf(((Datetime) val).date());
            }
            return String.valueOf(Date.valueOf(String.valueOf(val)));
        } catch (Exception e) {
            System.debug('==extractTagDate error== ' + e.getMessage());
            return null;
        }
    }*/
    
private static String extractTagDate(
Map<String, Object> tags,
String key
) {
if (tags == null || !tags.containsKey(key)) return null;
try {
Object val =
    ((Map<String, Object>) tags.get(key)).get('tagValue');
if (val == null) return null;
if (val instanceof Datetime) {
    // ✅ Use dateGmt() to avoid UTC → local timezone shift
    return String.valueOf(((Datetime) val).dateGmt());
}
return String.valueOf(Date.valueOf(String.valueOf(val)));
} catch (Exception e) {
System.debug('==extractTagDate error== ' + e.getMessage());
return null;
}
}

    private static RevSignaling.TransactionResponse success(
        RevSignaling.TransactionResponse res,
        String msg
    ) {
        res.status  = RevSignaling.TransactionStatus.SUCCESS;
        res.message = msg;
        return res;
    }

    private static RevSignaling.TransactionResponse fail(
        RevSignaling.TransactionResponse res,
        String msg
    ) {
        res.status  = RevSignaling.TransactionStatus.FAILED;
        res.message = msg;
        return res;
    }

    // =========================================================
    // DTO
    // =========================================================
    public class TransactionContext {
        public String  quoteStartDate;
        public Integer contractTerm;
        public String  quoteId;
    }
}