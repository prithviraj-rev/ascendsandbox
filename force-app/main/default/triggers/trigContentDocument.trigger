trigger trigContentDocument on ContentDocument (after insert, after update) {
    
    public Set<Id> fIds = new Set<id>();
    for(ContentDocument cdn:trigger.new){
        fIds.add(cdn.id);
    }
    List<ContentVersion> cvs = [Select Id, ContentDocumentId, Type__c, title FROM ContentVersion WHERE ContentDocumentID in: fIds AND (Type__c =: 'MSA' OR Type__c =: 'MSA with NDA' OR Type__c =: 'NDA')];
    
    public Set<Id> cvIds = new Set<id>();
    public Set<Id> cdIds = new Set<id>();
    for(ContentVersion cv :cvs){
        boolean result = cv.title.startswith('MSA -') || cv.title.startswith('NDA -') || cv.title.startswith('MSA with NDA -');
        if(!result){
            system.debug('name: '+cv.title);
            cvIds.add(cv.Id);
            cdIds.add(cv.ContentDocumentId);
        }
    }
    
    system.debug(cdIds.size());
    If(cdIds.size() > 0){
        ContentDocumentName.FileName(cdIds);
        
    }
}