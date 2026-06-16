/******************************************************************************
// File Name:       AuraHelper
// Summary:         helper class for using in methods marked as AuraEnabled
// Created On:      03/18/2020
// Test Classes:    AuraHelperTest
// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 03/18/2020  - New Apex class created
*******************************************************************************/
public class AuraHelper {
    public class Response {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Object result { get; set; }

        @AuraEnabled public Map<String, Object> technicalData { get; set; }

        public Response() {
            this.success = true;
        }

        public Response(Object result) {
            this();

            if (result instanceof Exception) {
                Exception e = (Exception) result;

                this.success = false;
                this.message = e.getMessage();

                this.technicalData = buildTechnicalInformation(e);
            }
            else {
                this.result = result;
            }
        }

        public Response(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        private Map<String, Object> buildTechnicalInformation(Exception e) {
            return new Map<String, Object> {
                    'stackTrace' => e.getStackTraceString()
            };
        }
    }

    public class PicklistOption {
        public String value {get; set;}
        public String label {get; set;}

        public PicklistOption(String value, String label) {
            this.value = value;
            this.label = label;
        }

        public PicklistOption(Schema.PicklistEntry picklistEntry) {
            this(picklistEntry.getValue(), picklistEntry.getLabel());
        }
    }

    public class AuraException extends Exception {
    }
}