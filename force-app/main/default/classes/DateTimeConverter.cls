public class DateTimeConverter {
    
    @InvocableMethod(label='Convert DateTime to Chicago Timezone')
    public static List<Result> convertToChicago(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        TimeZone tz = TimeZone.getTimeZone('America/Chicago');
        
        for (Request req : requests) {
            Integer offsetMs = tz.getOffset(req.inputDateTime);
            DateTime convertedDT = req.inputDateTime.addSeconds(offsetMs / 1000);
            
            Result res = new Result();
            res.convertedDate = convertedDT.dateGmt();
            res.convertedDateTime = convertedDT;
            results.add(res);
        }
        return results;
    }
    
    public class Request {
        @InvocableVariable(required=true)
        public DateTime inputDateTime;
    }
    
    public class Result {
        @InvocableVariable
        public Date convertedDate;
        
        @InvocableVariable
        public DateTime convertedDateTime;
    }
}