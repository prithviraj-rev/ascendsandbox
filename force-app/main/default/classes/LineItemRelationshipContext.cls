public class LineItemRelationshipContext {

    public Map<String, String> childToParentMap { get; set; }
    public Map<String, Object> parentEndDateMap { get; set; }

    public LineItemRelationshipContext() {
        this.childToParentMap = new Map<String, String>();
        this.parentEndDateMap = new Map<String, Object>();
    }

    public static LineItemRelationshipContext build(
        List<Object> lineItems
    ) {
        LineItemRelationshipContext relCtx =
            new LineItemRelationshipContext();

        if (lineItems == null || lineItems.isEmpty()) return relCtx;

        for (Object item : lineItems) {
            LineItemNodeWrapper li = new LineItemNodeWrapper(item);
            if (!li.isValid() || li.deleted) continue;

            String lineId = (String) li.dataPath.get(2);

            if (String.isNotBlank(li.parentContextId)) {
                relCtx.childToParentMap.put(lineId, li.parentContextId);
            }
            if (li.endDate != null) {
                relCtx.parentEndDateMap.put(lineId, li.endDate);
            }
        }

        System.debug('LineItemRelationshipContext.build'
            + ' | childToParentMap: ' + relCtx.childToParentMap
            + ' | parentEndDateMap: ' + relCtx.parentEndDateMap
        );

        return relCtx;
    }

    public Object getParentEndDate(String childLineId) {
        String parentId = childToParentMap.get(childLineId);
        if (String.isBlank(parentId)) return null;
        return parentEndDateMap.get(parentId);
    }
}