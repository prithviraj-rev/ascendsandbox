public class TransactionContext {

    public String  quoteType;
    public Integer contractTerm;
    public String  quoteStartDate;
    public String  bookingDate;

    public TransactionContext() {}

    public Boolean isNewBusiness() { return quoteType == null; }
    public Boolean isAmend()       { return 'Amend'.equals(quoteType); }
    public Boolean isCancel()      { return 'Cancel'.equals(quoteType); }
}