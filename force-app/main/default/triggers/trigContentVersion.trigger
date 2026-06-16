trigger trigContentVersion on ContentVersion (after update) {
    
    public Set<Id> cvIds = new Set<id>();
    public Set<Id> cdIds = new Set<id>();
    for(ContentVersion cv :trigger.new){
        boolean result = (cv.title.startswith('MSA -') || cv.title.startswith('NDA -') || cv.title.startswith('MSA with NDA -')) && cv.New_Review_Created__c == FALSE;
        if(result){
            system.debug('name: '+cv.title);
            cvIds.add(cv.Id);
            cdIds.add(cv.ContentDocumentId);
        }
    }
    
    List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
    if(cdIds.size() > 0){
        cdlList = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE ContentDocumentId in: cdIds];
    }
    
    system.debug(cdIds.size());
    Map<String, Object> params = new Map<String, Object>();
    for(ContentDocumentLink cdl: cdlList){
        String lei = cdl.LinkedEntityId;
        params.clear();
        params.put('recordId', cdl.ContentDocumentId);
        params.put('varLEI', cdl.LinkedEntityId);
        if(lei.startsWith('001')){
            Flow.Interview.NewNDAReview ndaFlow = new Flow.Interview.NewNDAReview(params);
            ndaFlow.start();
        }
    }        
}