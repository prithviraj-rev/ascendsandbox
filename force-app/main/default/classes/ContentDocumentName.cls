public class ContentDocumentName {
    
    public static void FileName(Set<Id> fileIds){
        
        List<ContentVersion> cv = [Select id, type__c, createddate, title, Account_Name__c, Date_Signed__c FROM ContentVersion Where ContentDocumentId in: fileIds order by createddate desc limit 1];
        List<ContentVersion> newCVs = new List<ContentVersion>();
        
        for(ContentVersion c : cv){
            String formattedDate = c.Date_Signed__c.format();

            boolean result = c.title.startswith('MSA -') || c.title.startswith('NDA -') || c.title.startswith('MSA with NDA -');
            if(c.type__c != '' && !result){
                String cvName = c.type__c+' - '+c.Account_Name__c+' - '+formattedDate;
                c.title = cvName;
                newCVs.add(c);
                system.debug('name: '+c.title);
            }
        }
        if(newCVs.size() > 0){
            update newCVs;
            system.debug('name: '+newCVs[0].title);
        }
     
    }
}