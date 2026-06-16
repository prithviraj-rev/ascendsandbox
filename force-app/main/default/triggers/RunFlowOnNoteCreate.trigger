trigger RunFlowOnNoteCreate on ContentDocumentLink (after insert) {
    // Collect data
    Set<Id> oppIds = new Set<Id>();
    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith('006')) { // Opportunity prefix
            oppIds.add(cdl.LinkedEntityId);
        }
    }
    
    if (oppIds.isEmpty()) return;

    // Map Opportunity → Account
    Map<Id, Id> oppToAcctMap = new Map<Id, Id>();
    for (Opportunity opp : [
        SELECT Id, AccountId
        FROM Opportunity
        WHERE Id IN :oppIds AND AccountId != null
    ]) {
        oppToAcctMap.put(opp.Id, opp.AccountId);
    }

    List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
    Set<String> existingLinks = new Set<String>(); // to prevent duplicates

    // Query existing links for these documents to avoid duplication
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : Trigger.new) {
        docIds.add(cdl.ContentDocumentId);
    }
    for (ContentDocumentLink existing : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE ContentDocumentId IN :docIds
    ]) {
        existingLinks.add(existing.ContentDocumentId + '-' + existing.LinkedEntityId);
    }

    // Now create missing Account links
    for (ContentDocumentLink cdl : Trigger.new) {
        Id oppId = cdl.LinkedEntityId;
        Id acctId = oppToAcctMap.get(oppId);
        if (acctId == null) continue;

        // Get the related ContentDocument
        ContentDocument doc = [
            SELECT FileExtension
            FROM ContentDocument
            WHERE Id = :cdl.ContentDocumentId
            LIMIT 1
        ];

        // Only process Notes (.snote)
        if (doc.FileExtension != 'snote') continue;

        // Skip if already linked
        String key = cdl.ContentDocumentId + '-' + acctId;
        if (existingLinks.contains(key)) continue;

        linksToInsert.add(new ContentDocumentLink(
            ContentDocumentId = cdl.ContentDocumentId,
            LinkedEntityId = acctId,
            ShareType = 'V', // Viewer
            Visibility = 'AllUsers'
        ));
    }

    if (!linksToInsert.isEmpty()) {
        insert linksToInsert;
    }
}