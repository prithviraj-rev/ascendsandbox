global class QuoteMarginRollupPostHook implements RevSignaling.SignalingApexProcessor {

    private static Boolean alreadyExecuted = false;

    public RevSignaling.TransactionResponse execute(
        RevSignaling.TransactionRequest request
    ) {
        RevSignaling.TransactionResponse response =
            new RevSignaling.TransactionResponse();

        try {
            if (alreadyExecuted) {
                return success(response, 'Already executed — skipping');
            }
            alreadyExecuted = true;

            String contextId = request.ctxInstanceId;
            if (String.isBlank(contextId)) {
                return success(response, 'No contextId — skipping');
            }

            Context.IndustriesContext ctx = new Context.IndustriesContext();

            // Get Quote ID from context
            String quoteId = getQuoteId(contextId, ctx);
            System.debug('==QuoteMarginRollup quoteId== ' + quoteId);

            if (String.isBlank(quoteId)) {
                return success(response, 'No quoteId found — skipping');
            }

            // Fire async — DML not allowed inside pricing engine transaction
            QuoteMarginRollupPostHook.updateMarginAsync(quoteId);
            System.debug('==QuoteMarginRollup async fired for quoteId== ' + quoteId);

            return success(response, 'Margin rollup queued');

        } catch (Exception e) {
            System.debug('==QuoteMarginRollup EXCEPTION== ' + e.getMessage());
            System.debug('==QuoteMarginRollup STACK==     ' + e.getStackTraceString());
            return success(response, 'Hook error — skipped: ' + e.getMessage());
        }
    }

    // =========================================================
    // ASYNC METHOD — runs after pricing engine transaction closes
    // DML is safe here
    // =========================================================
    @future
    public static void updateMarginAsync(String quoteId) {
        try {
            System.debug('==updateMarginAsync START quoteId== ' + quoteId);

            Map<String, Decimal> lobMarginSum   = new Map<String, Decimal>();
            Map<String, Integer> lobMarginCount = new Map<String, Integer>();

            List<QuoteLineItem> qliList = [
                SELECT Id, Line_of_Business__c, Margin
                FROM   QuoteLineItem
                WHERE  QuoteId = :quoteId
                AND    Line_of_Business__c != null
                AND    Margin != null
            ];

            System.debug('==updateMarginAsync QLI count== ' + qliList.size());

            for (QuoteLineItem qli : qliList) {
                String  lob    = qli.Line_of_Business__c;
                Decimal margin = qli.Margin;

                System.debug('==QLI LOB=' + lob + ' | Margin=' + margin);

                Decimal currentSum   = lobMarginSum.containsKey(lob)   ? lobMarginSum.get(lob)   : 0;
                Integer currentCount = lobMarginCount.containsKey(lob) ? lobMarginCount.get(lob) : 0;

                lobMarginSum.put(lob,   currentSum + margin);
                lobMarginCount.put(lob, currentCount + 1);
            }

            System.debug('==LOB Sum Map==   ' + lobMarginSum);
            System.debug('==LOB Count Map== ' + lobMarginCount);

            // Build Quote update
            Quote q = new Quote(Id = quoteId);
            q.Service_Desk_Margin__c   = 0;
            q.Infrastructure_Margin__c = 0;
            q.Cybersecurity_Margin__c  = 0;
            q.Private_Cloud_Margin__c  = 0;
            q.VOIP_Margin__c           = 0;
            q.Onboarding_Margin__c     = 0;

            for (String lob : lobMarginSum.keySet()) {
                Decimal avg = (lobMarginSum.get(lob) / lobMarginCount.get(lob)).setScale(2);
                System.debug('==Setting ' + lob + ' = ' + avg);

                if      (lob == 'Service Desk')   q.Service_Desk_Margin__c   = avg;
                else if (lob == 'Infrastructure') q.Infrastructure_Margin__c = avg;
                else if (lob == 'Cybersecurity')  q.Cybersecurity_Margin__c  = avg;
                else if (lob == 'Private Cloud')  q.Private_Cloud_Margin__c  = avg;
                else if (lob == 'VOIP')           q.VOIP_Margin__c           = avg;
                else if (lob == 'Onboarding')     q.Onboarding_Margin__c     = avg;
            }

            update q;
            System.debug('==updateMarginAsync Quote DML SUCCESS==');

        } catch (Exception e) {
            System.debug('==updateMarginAsync EXCEPTION== ' + e.getMessage());
            System.debug('==updateMarginAsync STACK==     ' + e.getStackTraceString());
        }
    }

    // =========================================================
    // GET QUOTE ID — same pattern as JTLPreHook
    // =========================================================
    private static String getQuoteId(
        String contextId,
        Context.IndustriesContext ctx
    ) {
        Map<String, Object> res = ctx.queryTags(new Map<String, Object>{
            'contextId' => contextId,
            'tags'      => new List<String>{ 'SalesTransaction' }
        });

        Map<String, Object> queryResult = (Map<String, Object>) res.get('queryResult');
        if (queryResult == null) return null;

        List<Object> nodes = (List<Object>) queryResult.get('SalesTransaction');
        if (nodes == null || nodes.isEmpty()) return null;

        Map<String, Object> tags =
            (Map<String, Object>)
            ((Map<String, Object>) nodes.get(0)).get('tagValue');

        if (tags == null) return null;

        for (String key : tags.keySet()) {
            try {
                Object wrapper = tags.get(key);
                if (wrapper instanceof Map<String, Object>) {
                    Object val = ((Map<String, Object>) wrapper).get('tagValue');
                    if (val != null) {
                        String strVal = String.valueOf(val).trim();
                        if (strVal.startsWith('0Q0') && strVal.length() >= 15) {
                            return strVal;
                        }
                    }
                }
            } catch (Exception e) {}
        }

        return null;
    }

    // =========================================================
    // HELPER
    // =========================================================
    private static RevSignaling.TransactionResponse success(
        RevSignaling.TransactionResponse res,
        String msg
    ) {
        res.status  = RevSignaling.TransactionStatus.SUCCESS;
        res.message = msg;
        return res;
    }
}