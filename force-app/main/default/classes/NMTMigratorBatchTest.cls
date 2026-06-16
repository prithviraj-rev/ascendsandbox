/**
* @description 
* @author Dayana Daniel
*/
@isTest
public class NMTMigratorBatchTest {
    /**
* @description tests notes migration by Ids
* Test Case Name: Migrate by note id
* Test Case Name: Set a existing record id at migrate by note id
*/
    @isTest
    static void testNotestMigrationById(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact 
* - create two legacy note
* - get the ids
* - run the migration by Ids
* - assert 2 contentVersions were created
* - assert 2 CDLs were created
* - rerun the migration by Ids
* - assert 2 contentVersions were created
* - assert 2 CDLs were created
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create two legacy note
        List<Note> notes = NMTTestNoteUtils.createNoteForObject(2, c.Id, false);
        List<String> resultAux = new List<String>();
        //get the ids
        for(Note note:notes)
        {
            resultAux.add(note.Id);
        }
        
        //assert that 2 Legacy Notes were created
        System.assertEquals(2, resultAux.size(), '2 Legacy Notes created to migrate');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        
        NMTTestNoteUtils.sleep(10);
        
        //rerun the migration by Ids	
        batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 2 contentVersions were created
        System.assertEquals(2, contentVersions.size(), '2 Content Notes created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 2 CDLs were created
        System.assertEquals(2, cdls.size(), '2 Content Notes linked to the parent Contact');
        NAMUtils.lastContentDocument(0,10);
        }
    }
    
    
    /**
* @description tests notes migration by Object Ids
* Test Case Name: Migrate by record id from standard record
*/
    @isTest
    static void testNotestMigrationByObjectId(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a Contact
* - create a Product 
* - create two legacy note per owner
* - get the ids of the product and the contact
* - run the migration by Objects Ids
* - assert 4 contentVersions were created
* - assert 2 CDLs were created for each object
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        Product2 p = NMTTestNoteUtils.createProduct();
        //create two legacy notes for the Contact
        NMTTestNoteUtils.createNoteForObject(2, c.Id, false);
        //create two legacy notes for the Product
        NMTTestNoteUtils.createNoteForObject(2, p.Id, false);
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(c.Id);
        resultAux.add(p.Id);
        
        
        //assert that 2 Objects were created
        System.assertEquals(2, resultAux.size(), '2 Objects created to migrate their notes');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byObjectId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c != null];
        //assert 4 contentVersions were created
        System.assertEquals(4, contentVersions.size(), '4 Content Notes created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId in :resultAux
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        //assert 2 CDLs were created
        System.assertEquals(4, cdls.size(), '4 Content Notes linked to the parents ');
        }
    }
    
    /**
* @description tests notes migration by Object Names
* Test Case Name: Migrate record that has migrated and unmigrated legacy notes
*/
    @isTest
    static void testNotestMigrationByObjectName(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a Contact
* - create a Product 
* - create 100 legacy note per Contact
* - create 5 legacy note per Product
* - run the migration by Objects Names and 50 as quantity
* - rerun the migration by Objects Names and 5 as quantity
* - assert 60 contentVersions were created
* - assert 60 CDLs were created (55 for Contact and 5 for Product)
* - assert NotesPendingToConvert = 45
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        Product2 p = NMTTestNoteUtils.createProduct();
        //create 100 legacy notes for the Contact
        NMTTestNoteUtils.createNoteForObject(100, c.Id, false);
        //create 5 legacy notes for the Product public
        NMTTestNoteUtils.createNoteForObject(5, p.Id, false);
        //create 5 legacy notes for the Product private
        NMTTestNoteUtils.createNoteForObject(5, p.Id, true);
        
        Test.startTest();
        //run the migration by Objects Type	
        NMTMigratorBatch batch = new NMTMigratorBatch('Contact', null, 'byObject',50, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        NMTMigratorBatch batch2 = new NMTMigratorBatch('Product2', null, 'byObject',50, System.today(), System.today(), true);
        Id batchId2 = Database.executeBatch(batch2, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId2,'Convertion');
        NMTMigratorBatch batch3 = new NMTMigratorBatch('Contact', null, 'byObject',5, System.today(), System.today(), true);
        Id batchId3 = Database.executeBatch(batch3, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId3,'Convertion');
        NMTMigratorBatch batch4 = new NMTMigratorBatch('Product2', null, 'byObject',5, System.today(), System.today(), true);
        Id batchId4 = Database.executeBatch(batch4, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId4,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersion = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c != null];
        //assert 60 contentVersion were created
        System.assertEquals(65, contentVersion.size(), '65 Content Notes created');
        
        List<ContentDocumentLink> cdlsContact = [SELECT Id FROM ContentDocumentLink WHERE
                                                 linkedEntityId = :c.Id
                                                 AND
                                                 contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        List<ContentDocumentLink> cdlsProduct = [SELECT Id FROM ContentDocumentLink WHERE
                                                 linkedEntityId = :p.Id
                                                 AND
                                                 contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        
        //assert 65 CDLs were created (55 for Contact and 10 for Product)
        System.assertEquals(55, cdlsContact.size(), '55 Content Notes linked to the Contact ');
        System.assertEquals(10, cdlsProduct.size(), '10 Content Notes linked to the Product ');
        
        NAMNoteConversionStatus__c conversionStatus = NMTNoteConversionStatus.find().get(0);
        }
    }
    
    
    /**
* @description tests notes migration by unknown Ids 
*/
    @isTest
    static void testNotestMigrationByUnknownId(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - run the migration by unknown ids
* - assert 0 contentVersion were created
*/
        
        List<String> auxIds = new List<String>{'000000000000000', '111111111111111'};
            
            Test.startTest();
        //run the migration by Id	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, auxIds, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c != null];
        //assert 0 contentVersions were created
        System.assertEquals(0, contentVersions.size(), '0 Content Notes created');
        }
    }
    
    /**
* @description tests notes migration with invalid characters
* Test Case Name: Migrate note that has special characters
*/
    @isTest
    static void testNotestMigrationInvalidCharacters(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact 
* - create a legacy note with invalid characters in the body
* - get the id
* - run the migration by Id
* - assert 1 contentVersion is created
* - assert 1 CDL is created
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = 'Common: & “ ” ‘ ’ – — … ‐ ‒ ° © ® ™ • ½ ¼ ¾ ⅓ ⅔ † ‡ µ ¢ £ € « » ♠ ♣ ♥ ♦ ¿ �'
            +'Math: - × ÷ ± ∞ π ∅ ≤ ≥ ≠ ≈ ∧ ∨ ∩ ∪ ∈ ∀ ∃ ∄ ∑ ∏ ← ↑ → ↓ ↔ ↕ ↖ ↗ ↘ ↙ ↺ ↻ ⇒ ⇔'
            +'SuperSub: ⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁽ ⁾ ⁿ ⁱ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₍ ₎'
            +'u00A0:   ¡ ¢ £ ¤ ¥ ¦ § ¨ © ª « ¬ ­ ® ¯ ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿'
            +'u00C0: À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï Ð Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü Ý Þ ß'
            +'u00E0: à á â ã ä å æ ç è é ê ë ì í î ï ð ñ ò ó ô õ ö ÷ ø ù ú û ü ý þ ÿ'
            +'u0100: Ā ā Ă ă Ą ą Ć ć Ĉ ĉ Ċ ċ Č č Ď ď Đ đ Ē ē Ĕ ĕ Ė ė Ę ę Ě ě Ĝ ĝ Ğ ğ'
            +'u0120: Ġ ġ Ģ ģ Ĥ ĥ Ħ ħ Ĩ ĩ Ī ī Ĭ ĭ Į į İ ı Ĳ ĳ Ĵ ĵ Ķ ķ ĸ Ĺ ĺ Ļ ļ Ľ ľ Ŀ'
            +'u0140: ŀ Ł ł Ń ń Ņ ņ Ň ň ŉ Ŋ ŋ Ō ō Ŏ ŏ Ő ő Œ œ Ŕ ŕ Ŗ ŗ Ř ř Ś ś Ŝ ŝ Ş ş'
            +'u0160: Š š Ţ ţ Ť ť Ŧ ŧ Ũ ũ Ū ū Ŭ ŭ Ů ů Ű ű Ų ų Ŵ ŵ Ŷ ŷ Ÿ Ź ź Ż ż Ž ž ſ'
            +'u0180: ƀ Ɓ Ƃ ƃ Ƅ ƅ Ɔ Ƈ ƈ Ɖ Ɗ Ƌ ƌ ƍ Ǝ Ə Ɛ Ƒ ƒ Ɠ Ɣ ƕ Ɩ Ɨ Ƙ ƙ ƚ ƛ Ɯ Ɲ ƞ Ɵ'
            +'u01A0: Ơ ơ Ƣ ƣ Ƥ ƥ Ʀ Ƨ ƨ Ʃ ƪ ƫ Ƭ ƭ Ʈ Ư ư Ʊ Ʋ Ƴ ƴ Ƶ ƶ Ʒ Ƹ ƹ ƺ ƻ Ƽ ƽ ƾ ƿ'
            +'u01C0: ǀ ǁ ǂ ǃ Ǆ ǅ ǆ Ǉ ǈ ǉ Ǌ ǋ ǌ Ǎ ǎ Ǐ ǐ Ǒ ǒ Ǔ ǔ Ǖ ǖ Ǘ ǘ Ǚ ǚ Ǜ ǜ ǝ Ǟ ǟ'
            +'u01E0: Ǡ ǡ Ǣ ǣ Ǥ ǥ Ǧ ǧ Ǩ ǩ Ǫ ǫ Ǭ ǭ Ǯ ǯ ǰ Ǳ ǲ ǳ Ǵ ǵ Ƕ Ƿ Ǹ ǹ Ǻ ǻ Ǽ ǽ Ǿ ǿ'
            +'u0200: Ȁ ȁ Ȃ ȃ Ȅ ȅ Ȇ ȇ Ȉ ȉ Ȋ ȋ Ȍ ȍ Ȏ ȏ Ȑ ȑ Ȓ ȓ Ȕ ȕ Ȗ ȗ Ș ș Ț ț Ȝ ȝ Ȟ ȟ'
            +'u0220: Ƞ ȡ Ȣ ȣ Ȥ ȥ Ȧ ȧ Ȩ ȩ Ȫ ȫ Ȭ ȭ Ȯ ȯ Ȱ ȱ Ȳ ȳ ȴ ȵ ȶ ȷ ȸ ȹ Ⱥ Ȼ ȼ Ƚ Ⱦ ȿ'
            +'u0240: ɀ Ɂ ɂ Ƀ Ʉ Ʌ Ɇ ɇ Ɉ ɉ Ɋ ɋ Ɍ ɍ Ɏ ɏ ɐ ɑ ɒ ɓ ɔ ɕ ɖ ɗ ɘ ə ɚ ɛ ɜ ɝ ɞ ɟ'
            +'u0260: ɠ ɡ ɢ ɣ ɤ ɥ ɦ ɧ ɨ ɩ ɪ ɫ ɬ ɭ ɮ ɯ ɰ ɱ ɲ ɳ ɴ ɵ ɶ ɷ ɸ ɹ ɺ ɻ ɼ ɽ ɾ ɿ'
            +'u0280: ʀ ʁ ʂ ʃ ʄ ʅ ʆ ʇ ʈ ʉ ʊ ʋ ʌ ʍ ʎ ʏ ʐ ʑ ʒ ʓ ʔ ʕ ʖ ʗ ʘ ʙ ʚ ʛ ʜ ʝ ʞ ʟ'
            +'u02A0: ʠ ʡ ʢ ʣ ʤ ʥ ʦ ʧ ʨ ʩ ʪ ʫ ʬ ʭ ʮ ʯ ʰ ʱ ʲ ʳ ʴ ʵ ʶ ʷ ʸ ʹ ʺ ʻ ʼ ʽ ʾ ʿ'
            +'u02C0: ˀ ˁ ˂ ˃ ˄ ˅ ˆ ˇ ˈ ˉ ˊ ˋ ˌ ˍ ˎ ˏ ː ˑ ˒ ˓ ˔ ˕ ˖ ˗ ˘ ˙ ˚ ˛ ˜ ˝ ˞ ˟'
            +'u02E0: ˠ ˡ ˢ ˣ ˤ ˥ ˦ ˧ ˨ ˩ ˪ ˫ ˬ ˭ ˮ ˯ ˰ ˱ ˲ ˳ ˴ ˵ ˶ ˷ ˸ ˹ ˺ ˻ ˼ ˽ ˾ ˿'
            +'u0300: ̀ ́ ̂ ̃ ̄ ̅ ̆ ̇ ̈ ̉ ̊ ̋ ̌ ̍ ̎ ̏ ̐ ̑ ̒ ̓ ̔ ̕ ̖ ̗ ̘ ̙ ̚ ̛ ̜ ̝ ̞ ̟'
            +'u0320: ̠ ̡ ̢ ̣ ̤ ̥ ̦ ̧ ̨ ̩ ̪ ̫ ̬ ̭ ̮ ̯ ̰ ̱ ̲ ̳ ̴ ̵ ̶ ̷ ̸ ̹ ̺ ̻ ̼ ̽ ̾ ̿'
            +'u0340: ̀ ́ ͂ ̓ ̈́ ͅ ͆ ͇ ͈ ͉ ͊ ͋ ͌ ͍ ͎ ͏ ͐ ͑ ͒ ͓ ͔ ͕ ͖ ͗ ͘ ͙ ͚ ͛ ͜ ͝ ͞ ͟'
            +'u0360: ͠ ͡ ͢ ͣ ͤ ͥ ͦ ͧ ͨ ͩ ͪ ͫ ͬ ͭ ͮ ͯ Ͱ ͱ Ͳ ͳ ʹ ͵ Ͷ ͷ ͸ ͹ ͺ ͻ ͼ ͽ ; Ϳ'
            +'u0380: ΀ ΁ ΂ ΃ ΄ ΅ Ά · Έ Ή Ί ΋ Ό ΍ Ύ Ώ ΐ Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο'
            +'u03A0: Π Ρ ΢ Σ Τ Υ Φ Χ Ψ Ω Ϊ Ϋ ά έ ή ί ΰ α β γ δ ε ζ η θ ι κ λ μ ν ξ ο'
            +'u03C0: π ρ ς σ τ υ φ χ ψ ω ϊ ϋ ό ύ ώ Ϗ ϐ ϑ ϒ ϓ ϔ ϕ ϖ ϗ Ϙ ϙ Ϛ ϛ Ϝ ϝ Ϟ ϟ'
            +'u03E0: Ϡ ϡ Ϣ ϣ Ϥ ϥ Ϧ ϧ Ϩ ϩ Ϫ ϫ Ϭ ϭ Ϯ ϯ ϰ ϱ ϲ ϳ ϴ ϵ ϶ Ϸ ϸ Ϲ Ϻ ϻ ϼ Ͻ Ͼ Ͽ'
            +'u0400: Ѐ Ё Ђ Ѓ Є Ѕ І Ї Ј Љ Њ Ћ Ќ Ѝ Ў Џ А Б В Г Д Е Ж З И Й К Л М Н О П'
            +'u0420: Р С Т У Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я а б в г д е ж з и й к л м н о п'
            +'u0440: р с т у ф х ц ч ш щ ъ ы ь э ю я ѐ ё ђ ѓ є ѕ і ї ј љ њ ћ ќ ѝ ў џ'
            +'u0460: Ѡ ѡ Ѣ ѣ Ѥ ѥ Ѧ ѧ Ѩ ѩ Ѫ ѫ Ѭ ѭ Ѯ ѯ Ѱ ѱ Ѳ ѳ Ѵ ѵ Ѷ ѷ Ѹ ѹ Ѻ ѻ Ѽ ѽ Ѿ ѿ'
            +'u0480: Ҁ ҁ ҂ ҃ ҄ ҅ ҆ ҇ ҈ ҉ Ҋ ҋ Ҍ ҍ Ҏ ҏ Ґ ґ Ғ ғ Ҕ ҕ Җ җ Ҙ ҙ Қ қ Ҝ ҝ Ҟ ҟu04A0: Ҡ ҡ Ң ң Ҥ ҥ Ҧ ҧ Ҩ ҩ Ҫ ҫ Ҭ ҭ Ү ү Ұ ұ Ҳ ҳ Ҵ ҵ Ҷ ҷ Ҹ ҹ Һ һ Ҽ ҽ Ҿ ҿ'
            +'u04C0: Ӏ Ӂ ӂ Ӄ ӄ Ӆ ӆ Ӈ ӈ Ӊ ӊ Ӌ ӌ Ӎ ӎ ӏ Ӑ ӑ Ӓ ӓ Ӕ ӕ Ӗ ӗ Ә ә Ӛ ӛ Ӝ ӝ Ӟ ӟ'
            +'u04E0: Ӡ ӡ Ӣ ӣ Ӥ ӥ Ӧ ӧ Ө ө Ӫ ӫ Ӭ ӭ Ӯ ӯ Ӱ ӱ Ӳ ӳ Ӵ ӵ Ӷ ӷ Ӹ ӹ Ӻ ӻ Ӽ ӽ Ӿ ӿ'
            +'u0500: Ԁ ԁ Ԃ ԃ Ԅ ԅ Ԇ ԇ Ԉ ԉ Ԋ ԋ Ԍ ԍ Ԏ ԏ Ԑ ԑ Ԓ ԓ Ԕ ԕ Ԗ ԗ Ԙ ԙ Ԛ ԛ Ԝ ԝ Ԟ ԟ'
            +'u0520: Ԡ ԡ Ԣ ԣ Ԥ ԥ Ԧ ԧ Ԩ ԩ Ԫ ԫ Ԭ ԭ Ԯ ԯ ԰ Ա Բ Գ Դ Ե Զ Է Ը Թ Ժ Ի Լ Խ Ծ Կ'
            +'u0620: ؠء آ أ ؤ إ ئ ا ب ة ت ث ج ح خ د ذ ر ز س ش ص ض ط ظ ع غ ػ ؼ ؽ ؾ ؿ'
            +'u0640: ـ ف ق ك ل م ن ه و ى ي ً ٌ ٍ َ ُ ِ ّ ْ ٓ ٔ ٕ ٖ ٗ ٘ ٙ ٚ ٛ ٜ ٝ ٞ ٟ'
            +'u0660: ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ ٪ ٫ ٬ ٭ ٮ ٯ ٰ ٱ ٲ ٳ ٴ ٵ ٶ ٷ ٸ ٹ ٺ ٻ ټ ٽ پ ٿ'
            +'u0680: ڀ ځ ڂ ڃ ڄ څ چ ڇ ڈ ډ ڊ ڋ ڌ ڍ ڎ ڏ ڐ ڑ ڒ ړ ڔ ڕ ږ ڗ ژ ڙ ښ ڛ ڜ ڝ ڞ ڟ'
            +'u0900: ऀ ँ ं ः ऄ अ आ इ ई उ ऊ ऋ ऌ ऍ ऎ ए ऐ ऑ ऒ ओ औ क ख ग घ ङ च छ ज झ ञ ट'
            +'u0920: ठ ड ढ ण त थ द ध न ऩ प फ ब भ म य र ऱ ल ळ ऴ व श ष स ह ऺ ऻ ़ ऽ ा ि'
            +'u0940: ी ु ू ृ ॄ ॅ ॆ े ै ॉ ॊ ो ौ ् ॎ ॏ ॐ ॑ ॒ ॓ ॔ ॕ ॖ ॗ क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़'
            +'u0FC0: ࿀ ࿁ ࿂ ࿃ ࿄ ࿅ ࿆ ࿇ ࿈ ࿉ ࿊ ࿋ ࿌ ࿍ ࿎ ࿏ ࿐ ࿑ ࿒ ࿓ ࿔ ࿕ ࿖ ࿗ ࿘ ࿙ ࿚ ࿛ ࿜ ࿝ ࿞ ࿟'
            +'u10A0: Ⴀ Ⴁ Ⴂ Ⴃ Ⴄ Ⴅ Ⴆ Ⴇ Ⴈ Ⴉ Ⴊ Ⴋ Ⴌ Ⴍ Ⴎ Ⴏ Ⴐ Ⴑ Ⴒ Ⴓ Ⴔ Ⴕ Ⴖ Ⴗ Ⴘ Ⴙ Ⴚ Ⴛ Ⴜ Ⴝ Ⴞ Ⴟ'
            +'u13A0: Ꭰ Ꭱ Ꭲ Ꭳ Ꭴ Ꭵ Ꭶ Ꭷ Ꭸ Ꭹ Ꭺ Ꭻ Ꭼ Ꭽ Ꭾ Ꭿ Ꮀ Ꮁ Ꮂ Ꮃ Ꮄ Ꮅ Ꮆ Ꮇ Ꮈ Ꮉ Ꮊ Ꮋ Ꮌ Ꮍ Ꮎ Ꮏ'
            +'u1400: ᐀ ᐁ ᐂ ᐃ ᐄ ᐅ ᐆ ᐇ ᐈ ᐉ ᐊ ᐋ ᐌ ᐍ ᐎ ᐏ ᐐ ᐑ ᐒ ᐓ ᐔ ᐕ ᐖ ᐗ ᐘ ᐙ ᐚ ᐛ ᐜ ᐝ ᐞ ᐟ'
            +'u1580: ᖀ ᖁ ᖂ ᖃ ᖄ ᖅ ᖆ ᖇ ᖈ ᖉ ᖊ ᖋ ᖌ ᖍ ᖎ ᖏ ᖐ ᖑ ᖒ ᖓ ᖔ ᖕ ᖖ ᖗ ᖘ ᖙ ᖚ ᖛ ᖜ ᖝ ᖞ ᖟ'
            +'u1680:   ᚁ ᚂ ᚃ ᚄ ᚅ ᚆ ᚇ ᚈ ᚉ ᚊ ᚋ ᚌ ᚍ ᚎ ᚏ ᚐ ᚑ ᚒ ᚓ ᚔ ᚕ ᚖ ᚗ ᚘ ᚙ ᚚ ᚛ ᚜ ᚝ ᚞ ᚟'
            +'u16A0: ᚠ ᚡ ᚢ ᚣ ᚤ ᚥ ᚦ ᚧ ᚨ ᚩ ᚪ ᚫ ᚬ ᚭ ᚮ ᚯ ᚰ ᚱ ᚲ ᚳ ᚴ ᚵ ᚶ ᚷ ᚸ ᚹ ᚺ ᚻ ᚼ ᚽ ᚾ ᚿ'
            +'u16C0: ᛀ ᛁ ᛂ ᛃ ᛄ ᛅ ᛆ ᛇ ᛈ ᛉ ᛊ ᛋ ᛌ ᛍ ᛎ ᛏ ᛐ ᛑ ᛒ ᛓ ᛔ ᛕ ᛖ ᛗ ᛘ ᛙ ᛚ ᛛ ᛜ ᛝ ᛞ ᛟ'
            +'u16E0: ᛠ ᛡ ᛢ ᛣ ᛤ ᛥ ᛦ ᛧ ᛨ ᛩ ᛪ ᛫ ᛬ ᛭ ᛮ ᛯ ᛰ ᛱ ᛲ ᛳ ᛴ ᛵ ᛶ ᛷ ᛸ ᛹ ᛺ ᛻ ᛼ ᛽ ᛾ ᛿'
            +'u1D00: ᴀ ᴁ ᴂ ᴃ ᴄ ᴅ ᴆ ᴇ ᴈ ᴉ ᴊ ᴋ ᴌ ᴍ ᴎ ᴏ ᴐ ᴑ ᴒ ᴓ ᴔ ᴕ ᴖ ᴗ ᴘ ᴙ ᴚ ᴛ ᴜ ᴝ ᴞ ᴟ'
            +'u1D20: ᴠ ᴡ ᴢ ᴣ ᴤ ᴥ ᴦ ᴧ ᴨ ᴩ ᴪ ᴫ ᴬ ᴭ ᴮ ᴯ ᴰ ᴱ ᴲ ᴳ ᴴ ᴵ ᴶ ᴷ ᴸ ᴹ ᴺ ᴻ ᴼ ᴽ ᴾ ᴿ'
            +'u1D40: ᵀ ᵁ ᵂ ᵃ ᵄ ᵅ ᵆ ᵇ ᵈ ᵉ ᵊ ᵋ ᵌ ᵍ ᵎ ᵏ ᵐ ᵑ ᵒ ᵓ ᵔ ᵕ ᵖ ᵗ ᵘ ᵙ ᵚ ᵛ ᵜ ᵝ ᵞ ᵟ'
            +'u1E00: Ḁ ḁ Ḃ ḃ Ḅ ḅ Ḇ ḇ Ḉ ḉ Ḋ ḋ Ḍ ḍ Ḏ ḏ Ḑ ḑ Ḓ ḓ Ḕ ḕ Ḗ ḗ Ḙ ḙ Ḛ ḛ Ḝ ḝ Ḟ ḟ'
            +'u1E20: Ḡ ḡ Ḣ ḣ Ḥ ḥ Ḧ ḧ Ḩ ḩ Ḫ ḫ Ḭ ḭ Ḯ ḯ Ḱ ḱ Ḳ ḳ Ḵ ḵ Ḷ ḷ Ḹ ḹ Ḻ ḻ Ḽ ḽ Ḿ ḿ'
            +'u1E40: Ṁ ṁ Ṃ ṃ Ṅ ṅ Ṇ ṇ Ṉ ṉ Ṋ ṋ Ṍ ṍ Ṏ ṏ Ṑ ṑ Ṓ ṓ Ṕ ṕ Ṗ ṗ Ṙ ṙ Ṛ ṛ Ṝ ṝ Ṟ ṟ'
            +'u1E60: Ṡ ṡ Ṣ ṣ Ṥ ṥ Ṧ ṧ Ṩ ṩ Ṫ ṫ Ṭ ṭ Ṯ ṯ Ṱ ṱ Ṳ ṳ Ṵ ṵ Ṷ ṷ Ṹ ṹ Ṻ ṻ Ṽ ṽ Ṿ ṿ'
            +'u1E80: Ẁ ẁ Ẃ ẃ Ẅ ẅ Ẇ ẇ Ẉ ẉ Ẋ ẋ Ẍ ẍ Ẏ ẏ Ẑ ẑ Ẓ ẓ Ẕ ẕ ẖ ẗ ẘ ẙ ẚ ẛ ẜ ẝ ẞ ẟ'
            +'u1EA0: Ạ ạ Ả ả Ấ ấ Ầ ầ Ẩ ẩ Ẫ ẫ Ậ ậ Ắ ắ Ằ ằ Ẳ ẳ Ẵ ẵ Ặ ặ Ẹ ẹ Ẻ ẻ Ẽ ẽ Ế ế'
            +'u1EC0: Ề ề Ể ể Ễ ễ Ệ ệ Ỉ ỉ Ị ị Ọ ọ Ỏ ỏ Ố ố Ồ ồ Ổ ổ Ỗ ỗ Ộ ộ Ớ ớ Ờ ờ Ở ở'
            +'u1EE0: Ỡ ỡ Ợ ợ Ụ ụ Ủ ủ Ứ ứ Ừ ừ Ử ử Ữ ữ Ự ự Ỳ ỳ Ỵ ỵ Ỷ ỷ Ỹ ỹ Ỻ ỻ Ỽ ỽ Ỿ ỿ'
            +'u1F00: ἀ ἁ ἂ ἃ ἄ ἅ ἆ ἇ Ἀ Ἁ Ἂ Ἃ Ἄ Ἅ Ἆ Ἇ ἐ ἑ ἒ ἓ ἔ ἕ ἖ ἗ Ἐ Ἑ Ἒ Ἓ Ἔ Ἕ ἞ ἟'
            +'u1F20: ἠ ἡ ἢ ἣ ἤ ἥ ἦ ἧ Ἠ Ἡ Ἢ Ἣ Ἤ Ἥ Ἦ Ἧ ἰ ἱ ἲ ἳ ἴ ἵ ἶ ἷ Ἰ Ἱ Ἲ Ἳ Ἴ Ἵ Ἶ Ἷ'
            +'u1F40: ὀ ὁ ὂ ὃ ὄ ὅ ὆ ὇ Ὀ Ὁ Ὂ Ὃ Ὄ Ὅ ὎ ὏ ὐ ὑ ὒ ὓ ὔ ὕ ὖ ὗ ὘ Ὑ ὚ Ὓ ὜ Ὕ ὞ Ὗ'
            +'u1F60: ὠ ὡ ὢ ὣ ὤ ὥ ὦ ὧ Ὠ Ὡ Ὢ Ὣ Ὤ Ὥ Ὦ Ὧ ὰ ά ὲ έ ὴ ή ὶ ί ὸ ό ὺ ύ ὼ ώ ὾ ὿'
            +'u1F80: ᾀ ᾁ ᾂ ᾃ ᾄ ᾅ ᾆ ᾇ ᾈ ᾉ ᾊ ᾋ ᾌ ᾍ ᾎ ᾏ ᾐ ᾑ ᾒ ᾓ ᾔ ᾕ ᾖ ᾗ ᾘ ᾙ ᾚ ᾛ ᾜ ᾝ ᾞ ᾟ'
            +'u1FA0: ᾠ ᾡ ᾢ ᾣ ᾤ ᾥ ᾦ ᾧ ᾨ ᾩ ᾪ ᾫ ᾬ ᾭ ᾮ ᾯ ᾰ ᾱ ᾲ ᾳ ᾴ ᾵ ᾶ ᾷ Ᾰ Ᾱ Ὰ Ά ᾼ ᾽ ι ᾿'
            +'u1FC0: ῀ ῁ ῂ ῃ ῄ ῅ ῆ ῇ Ὲ Έ Ὴ Ή ῌ ῍ ῎ ῏ ῐ ῑ ῒ ΐ ῔ ῕ ῖ ῗ Ῐ Ῑ Ὶ Ί ῜ ῝ ῞ ῟'
            +'u1FE0: ῠ ῡ ῢ ΰ ῤ ῥ ῦ ῧ Ῠ Ῡ Ὺ Ύ Ῥ ῭ ΅ ` ῰ ῱ ῲ ῳ ῴ ῵ ῶ ῷ Ὸ Ό Ὼ Ώ ῼ ´ ῾ ῿'
            +'u2000:                        ‌ ‍ ‎ ‏ ‐ ‑ ‒ – — ― ‖ ‗ ‘ ’ ‚ ‛ “ ” „ ‟'
            +'u2020:† ‡ • ‣ ․ ‥ … ‧\u2029\u2028 ‭ ‮   ‰ ‱ ′ ″ ‴ ‵ ‶ ‷ ‸ ‹ › ※ ‼ ‽ ‾ ‿'
            +'u2040: ⁀ ⁁ ⁂ ⁃ ⁄ ⁅ ⁆ ⁇ ⁈ ⁉ ⁊ ⁋ ⁌ ⁍ ⁎ ⁏ ⁐ ⁑ ⁒ ⁓ ⁔ ⁕ ⁖ ⁗ ⁘ ⁙ ⁚ ⁛ ⁜ ⁝ ⁞  '
            +'u2060: ⁠ ⁡ ⁢ ⁣ ⁤ ⁥ ⁦ ⁧ ⁨ ⁩       ⁰ ⁱ ⁲ ⁳ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁼ ⁽ ⁾ ⁿ'
            +'u2080: ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₍ ₎ ₏ ₐ ₑ ₒ ₓ ₔ ₕ ₖ ₗ ₘ ₙ ₚ ₛ ₜ ₝ ₞ ₟'
            +'u20A0: ₠ ₡ ₢ ₣ ₤ ₥ ₦ ₧ ₨ ₩ ₪ ₫ € ₭ ₮ ₯ ₰ ₱ ₲ ₳ ₴ ₵ ₶ ₷ ₸ ₹ ₺ ₻ ₼ ₽ ₾ ₿'
            +'u20C0: ⃀ ⃁ ⃂ ⃃ ⃄ ⃅ ⃆ ⃇ ⃈ ⃉ ⃊ ⃋ ⃌ ⃍ ⃎ ⃏ ⃐ ⃑ ⃒ ⃓ ⃔ ⃕ ⃖ ⃗ ⃘ ⃙ ⃚ ⃛ ⃜ ⃝ ⃞ ⃟'
            +'u20E0: ⃠ ⃡ ⃢ ⃣ ⃤ ⃥ ⃦ ⃧ ⃨ ⃩ ⃪ ⃫ ⃬ ⃭ ⃮ ⃯ ⃰ ⃱ ⃲ ⃳ ⃴ ⃵ ⃶ ⃷ ⃸ ⃹ ⃺ ⃻ ⃼ ⃽ ⃾ ⃿'
            +'u2100: ℀ ℁ ℂ ℃ ℄ ℅ ℆ ℇ ℈ ℉ ℊ ℋ ℌ ℍ ℎ ℏ ℐ ℑ ℒ ℓ ℔ ℕ № ℗ ℘ ℙ ℚ ℛ ℜ ℝ ℞ ℟'
            +'u2120: ℠ ℡ ™ ℣ ℤ ℥ Ω ℧ ℨ ℩ K Å ℬ ℭ ℮ ℯ ℰ ℱ Ⅎ ℳ ℴ ℵ ℶ ℷ ℸ ℹ ℺ ℻ ℼ ℽ ℾ ℿ'
            +'u2140: ⅀ ⅁ ⅂ ⅃ ⅄ ⅅ ⅆ ⅇ ⅈ ⅉ ⅊ ⅋ ⅌ ⅍ ⅎ ⅏ ⅐ ⅑ ⅒ ⅓ ⅔ ⅕ ⅖ ⅗ ⅘ ⅙ ⅚ ⅛ ⅜ ⅝ ⅞ ⅟'
            +'u2160: Ⅰ Ⅱ Ⅲ Ⅳ Ⅴ Ⅵ Ⅶ Ⅷ Ⅸ Ⅹ Ⅺ Ⅻ Ⅼ Ⅽ Ⅾ Ⅿ ⅰ ⅱ ⅲ ⅳ ⅴ ⅵ ⅶ ⅷ ⅸ ⅹ ⅺ ⅻ ⅼ ⅽ ⅾ ⅿ'
            +'u2180: ↀ ↁ ↂ Ↄ ↄ ↅ ↆ ↇ ↈ ↉ ↊ ↋ ↌ ↍ ↎ ↏ ← ↑ → ↓ ↔ ↕ ↖ ↗ ↘ ↙ ↚ ↛ ↜ ↝ ↞ ↟'
            +'u21A0: ↠ ↡ ↢ ↣ ↤ ↥ ↦ ↧ ↨ ↩ ↪ ↫ ↬ ↭ ↮ ↯ ↰ ↱ ↲ ↳ ↴ ↵ ↶ ↷ ↸ ↹ ↺ ↻ ↼ ↽ ↾ ↿'
            +'u21C0: ⇀ ⇁ ⇂ ⇃ ⇄ ⇅ ⇆ ⇇ ⇈ ⇉ ⇊ ⇋ ⇌ ⇍ ⇎ ⇏ ⇐ ⇑ ⇒ ⇓ ⇔ ⇕ ⇖ ⇗ ⇘ ⇙ ⇚ ⇛ ⇜ ⇝ ⇞ ⇟'
            +'u21E0: ⇠ ⇡ ⇢ ⇣ ⇤ ⇥ ⇦ ⇧ ⇨ ⇩ ⇪ ⇫ ⇬ ⇭ ⇮ ⇯ ⇰ ⇱ ⇲ ⇳ ⇴ ⇵ ⇶ ⇷ ⇸ ⇹ ⇺ ⇻ ⇼ ⇽ ⇾ ⇿'
            +'u2200: ∀ ∁ ∂ ∃ ∄ ∅ ∆ ∇ ∈ ∉ ∊ ∋ ∌ ∍ ∎ ∏ ∐ ∑ − ∓ ∔ ∕ ∖ ∗ ∘ ∙ √ ∛ ∜ ∝ ∞ ∟'
            +'u2220: ∠ ∡ ∢ ∣ ∤ ∥ ∦ ∧ ∨ ∩ ∪ ∫ ∬ ∭ ∮ ∯ ∰ ∱ ∲ ∳ ∴ ∵ ∶ ∷ ∸ ∹ ∺ ∻ ∼ ∽ ∾ ∿'
            +'u2240: ≀ ≁ ≂ ≃ ≄ ≅ ≆ ≇ ≈ ≉ ≊ ≋ ≌ ≍ ≎ ≏ ≐ ≑ ≒ ≓ ≔ ≕ ≖ ≗ ≘ ≙ ≚ ≛ ≜ ≝ ≞ ≟'
            +'u2260: ≠ ≡ ≢ ≣ ≤ ≥ ≦ ≧ ≨ ≩ ≪ ≫ ≬ ≭ ≮ ≯ ≰ ≱ ≲ ≳ ≴ ≵ ≶ ≷ ≸ ≹ ≺ ≻ ≼ ≽ ≾ ≿'
            +'u2280: ⊀ ⊁ ⊂ ⊃ ⊄ ⊅ ⊆ ⊇ ⊈ ⊉ ⊊ ⊋ ⊌ ⊍ ⊎ ⊏ ⊐ ⊑ ⊒ ⊓ ⊔ ⊕ ⊖ ⊗ ⊘ ⊙ ⊚ ⊛ ⊜ ⊝ ⊞ ⊟'
            +'u22A0: ⊠ ⊡ ⊢ ⊣ ⊤ ⊥ ⊦ ⊧ ⊨ ⊩ ⊪ ⊫ ⊬ ⊭ ⊮ ⊯ ⊰ ⊱ ⊲ ⊳ ⊴ ⊵ ⊶ ⊷ ⊸ ⊹ ⊺ ⊻ ⊼ ⊽ ⊾ ⊿'
            +'u22C0: ⋀ ⋁ ⋂ ⋃ ⋄ ⋅ ⋆ ⋇ ⋈ ⋉ ⋊ ⋋ ⋌ ⋍ ⋎ ⋏ ⋐ ⋑ ⋒ ⋓ ⋔ ⋕ ⋖ ⋗ ⋘ ⋙ ⋚ ⋛ ⋜ ⋝ ⋞ ⋟'
            +'u22E0: ⋠ ⋡ ⋢ ⋣ ⋤ ⋥ ⋦ ⋧ ⋨ ⋩ ⋪ ⋫ ⋬ ⋭ ⋮ ⋯ ⋰ ⋱ ⋲ ⋳ ⋴ ⋵ ⋶ ⋷ ⋸ ⋹ ⋺ ⋻ ⋼ ⋽ ⋾ ⋿'
            +'u2300: ⌀ ⌁ ⌂ ⌃ ⌄ ⌅ ⌆ ⌇ ⌈ ⌉ ⌊ ⌋ ⌌ ⌍ ⌎ ⌏ ⌐ ⌑ ⌒ ⌓ ⌔ ⌕ ⌖ ⌗ ⌘ ⌙ ⌚ ⌛ ⌜ ⌝ ⌞ ⌟'
            +'u2320: ⌠ ⌡ ⌢ ⌣ ⌤ ⌥ ⌦ ⌧ ⌨ 〈 〉 ⌫ ⌬ ⌭ ⌮ ⌯ ⌰ ⌱ ⌲ ⌳ ⌴ ⌵ ⌶ ⌷ ⌸ ⌹ ⌺ ⌻ ⌼ ⌽ ⌾ ⌿'
            +'u2340: ⍀ ⍁ ⍂ ⍃ ⍄ ⍅ ⍆ ⍇ ⍈ ⍉ ⍊ ⍋ ⍌ ⍍ ⍎ ⍏ ⍐ ⍑ ⍒ ⍓ ⍔ ⍕ ⍖ ⍗ ⍘ ⍙ ⍚ ⍛ ⍜ ⍝ ⍞ ⍟'
            +'u2360: ⍠ ⍡ ⍢ ⍣ ⍤ ⍥ ⍦ ⍧ ⍨ ⍩ ⍪ ⍫ ⍬ ⍭ ⍮ ⍯ ⍰ ⍱ ⍲ ⍳ ⍴ ⍵ ⍶ ⍷ ⍸ ⍹ ⍺ ⍻ ⍼ ⍽ ⍾ ⍿'
            +'u2380: ⎀ ⎁ ⎂ ⎃ ⎄ ⎅ ⎆ ⎇ ⎈ ⎉ ⎊ ⎋ ⎌ ⎍ ⎎ ⎏ ⎐ ⎑ ⎒ ⎓ ⎔ ⎕ ⎖ ⎗ ⎘ ⎙ ⎚ ⎛ ⎜ ⎝ ⎞ ⎟'
            +'u23A0: ⎠ ⎡ ⎢ ⎣ ⎤ ⎥ ⎦ ⎧ ⎨ ⎩ ⎪ ⎫ ⎬ ⎭ ⎮ ⎯ ⎰ ⎱ ⎲ ⎳ ⎴ ⎵ ⎶ ⎷ ⎸ ⎹ ⎺ ⎻ ⎼ ⎽ ⎾ ⎿'
            +'u23C0: ⏀ ⏁ ⏂ ⏃ ⏄ ⏅ ⏆ ⏇ ⏈ ⏉ ⏊ ⏋ ⏌ ⏍ ⏎ ⏏ ⏐ ⏑ ⏒ ⏓ ⏔ ⏕ ⏖ ⏗ ⏘ ⏙ ⏚ ⏛ ⏜ ⏝ ⏞ ⏟';
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
   
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
       /**
* @description tests notes migration with invalid characters
* Test Case Name: Migrate note that has special characters
*/    
   
    @isTest
    static void testNotestMigrationInvalidCharacters2(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = 'u23E0: ⏠ ⏡ ⏢ ⏣ ⏤ ⏥ ⏦ ⏧ ⏨ ⏩ ⏪ ⏫ ⏬ ⏭ ⏮ ⏯ ⏰ ⏱ ⏲ ⏳ ⏴ ⏵ ⏶ ⏷ ⏸ ⏹ ⏺ ⏻ ⏼ ⏽ ⏾ ⏿'
            +'u2400: ␀ ␁ ␂ ␃ ␄ ␅ ␆ ␇ ␈ ␉ ␊ ␋ ␌ ␍ ␎ ␏ ␐ ␑ ␒ ␓ ␔ ␕ ␖ ␗ ␘ ␙ ␚ ␛ ␜ ␝ ␞ ␟'
            +'u2420: ␠ ␡ ␢ ␣ ␤ ␥ ␦ ␧ ␨ ␩ ␪ ␫ ␬ ␭ ␮ ␯ ␰ ␱ ␲ ␳ ␴ ␵ ␶ ␷ ␸ ␹ ␺ ␻ ␼ ␽ ␾ ␿'
            +'u2440: ⑀ ⑁ ⑂ ⑃ ⑄ ⑅ ⑆ ⑇ ⑈ ⑉ ⑊ ⑋ ⑌ ⑍ ⑎ ⑏ ⑐ ⑑ ⑒ ⑓ ⑔ ⑕ ⑖ ⑗ ⑘ ⑙ ⑚ ⑛ ⑜ ⑝ ⑞ ⑟'
            +'u2460: ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ ⑪ ⑫ ⑬ ⑭ ⑮ ⑯ ⑰ ⑱ ⑲ ⑳ ⑴ ⑵ ⑶ ⑷ ⑸ ⑹ ⑺ ⑻ ⑼ ⑽ ⑾ ⑿'
            +'u2480: ⒀ ⒁ ⒂ ⒃ ⒄ ⒅ ⒆ ⒇ ⒈ ⒉ ⒊ ⒋ ⒌ ⒍ ⒎ ⒏ ⒐ ⒑ ⒒ ⒓ ⒔ ⒕ ⒖ ⒗ ⒘ ⒙ ⒚ ⒛ ⒜ ⒝ ⒞ ⒟'
            +'u24A0: ⒠ ⒡ ⒢ ⒣ ⒤ ⒥ ⒦ ⒧ ⒨ ⒩ ⒪ ⒫ ⒬ ⒭ ⒮ ⒯ ⒰ ⒱ ⒲ ⒳ ⒴ ⒵ Ⓐ Ⓑ Ⓒ Ⓓ Ⓔ Ⓕ Ⓖ Ⓗ Ⓘ Ⓙ'
            +'u24C0: Ⓚ Ⓛ Ⓜ Ⓝ Ⓞ Ⓟ Ⓠ Ⓡ Ⓢ Ⓣ Ⓤ Ⓥ Ⓦ Ⓧ Ⓨ Ⓩ ⓐ ⓑ ⓒ ⓓ ⓔ ⓕ ⓖ ⓗ ⓘ ⓙ ⓚ ⓛ ⓜ ⓝ ⓞ ⓟ'
            +'u24E0: ⓠ ⓡ ⓢ ⓣ ⓤ ⓥ ⓦ ⓧ ⓨ ⓩ ⓪ ⓫ ⓬ ⓭ ⓮ ⓯ ⓰ ⓱ ⓲ ⓳ ⓴ ⓵ ⓶ ⓷ ⓸ ⓹ ⓺ ⓻ ⓼ ⓽ ⓾ ⓿'
            +'u2500: ─ ━ │ ┃ ┄ ┅ ┆ ┇ ┈ ┉ ┊ ┋ ┌ ┍ ┎ ┏ ┐ ┑ ┒ ┓ └ ┕ ┖ ┗ ┘ ┙ ┚ ┛ ├ ┝ ┞ ┟'
            +'u2520: ┠ ┡ ┢ ┣ ┤ ┥ ┦ ┧ ┨ ┩ ┪ ┫ ┬ ┭ ┮ ┯ ┰ ┱ ┲ ┳ ┴ ┵ ┶ ┷ ┸ ┹ ┺ ┻ ┼ ┽ ┾ ┿'
            +'u2540: ╀ ╁ ╂ ╃ ╄ ╅ ╆ ╇ ╈ ╉ ╊ ╋ ╌ ╍ ╎ ╏ ═ ║ ╒ ╓ ╔ ╕ ╖ ╗ ╘ ╙ ╚ ╛ ╜ ╝ ╞ ╟'
            +'u2560: ╠ ╡ ╢ ╣ ╤ ╥ ╦ ╧ ╨ ╩ ╪ ╫ ╬ ╭ ╮ ╯ ╰ ╱ ╲ ╳ ╴ ╵ ╶ ╷ ╸ ╹ ╺ ╻ ╼ ╽ ╾ ╿'
            +'u2580: ▀ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▉ ▊ ▋ ▌ ▍ ▎ ▏ ▐ ░ ▒ ▓ ▔ ▕ ▖ ▗ ▘ ▙ ▚ ▛ ▜ ▝ ▞ ▟'
            +'u25A0: ■ □ ▢ ▣ ▤ ▥ ▦ ▧ ▨ ▩ ▪ ▫ ▬ ▭ ▮ ▯ ▰ ▱ ▲ △ ▴ ▵ ▶ ▷ ▸ ▹ ► ▻ ▼ ▽ ▾ ▿'
            +'u25C0: ◀ ◁ ◂ ◃ ◄ ◅ ◆ ◇ ◈ ◉ ◊ ○ ◌ ◍ ◎ ● ◐ ◑ ◒ ◓ ◔ ◕ ◖ ◗ ◘ ◙ ◚ ◛ ◜ ◝ ◞ ◟'
            +'u25E0: ◠ ◡ ◢ ◣ ◤ ◥ ◦ ◧ ◨ ◩ ◪ ◫ ◬ ◭ ◮ ◯ ◰ ◱ ◲ ◳ ◴ ◵ ◶ ◷ ◸ ◹ ◺ ◻ ◼ ◽ ◾ ◿'
            +'u2600: ☀ ☁ ☂ ☃ ☄ ★ ☆ ☇ ☈ ☉ ☊ ☋ ☌ ☍ ☎ ☏ ☐ ☑ ☒ ☓ ☔ ☕ ☖ ☗ ☘ ☙ ☚ ☛ ☜ ☝ ☞ ☟'
            +'u2620: ☠ ☡ ☢ ☣ ☤ ☥ ☦ ☧ ☨ ☩ ☪ ☫ ☬ ☭ ☮ ☯ ☰ ☱ ☲ ☳ ☴ ☵ ☶ ☷ ☸ ☹ ☺ ☻ ☼ ☽ ☾ ☿'
            +'u2640: ♀ ♁ ♂ ♃ ♄ ♅ ♆ ♇ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ ♔ ♕ ♖ ♗ ♘ ♙ ♚ ♛ ♜ ♝ ♞ ♟'
            +'u2660: ♠ ♡ ♢ ♣ ♤ ♥ ♦ ♧ ♨ ♩ ♪ ♫ ♬ ♭ ♮ ♯ ♰ ♱ ♲ ♳ ♴ ♵ ♶ ♷ ♸ ♹ ♺ ♻ ♼ ♽ ♾ ♿'
            +'u2680: ⚀ ⚁ ⚂ ⚃ ⚄ ⚅ ⚆ ⚇ ⚈ ⚉ ⚊ ⚋ ⚌ ⚍ ⚎ ⚏ ⚐ ⚑ ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙ ⚚ ⚛ ⚜ ⚝ ⚞ ⚟'
            +'u26A0: ⚠ ⚡ ⚢ ⚣ ⚤ ⚥ ⚦ ⚧ ⚨ ⚩ ⚪ ⚫ ⚬ ⚭ ⚮ ⚯ ⚰ ⚱ ⚲ ⚳ ⚴ ⚵ ⚶ ⚷ ⚸ ⚹ ⚺ ⚻ ⚼ ⚽ ⚾ ⚿'
            +'u2700: ✀ ✁ ✂ ✃ ✄ ✅ ✆ ✇ ✈ ✉ ✊ ✋ ✌ ✍ ✎ ✏ ✐ ✑ ✒ ✓ ✔ ✕ ✖ ✗ ✘ ✙ ✚ ✛ ✜ ✝ ✞ ✟'
            +'u2720: ✠ ✡ ✢ ✣ ✤ ✥ ✦ ✧ ✨ ✩ ✪ ✫ ✬ ✭ ✮ ✯ ✰ ✱ ✲ ✳ ✴ ✵ ✶ ✷ ✸ ✹ ✺ ✻ ✼ ✽ ✾ ✿'
            +'u2740: ❀ ❁ ❂ ❃ ❄ ❅ ❆ ❇ ❈ ❉ ❊ ❋ ❌ ❍ ❎ ❏ ❐ ❑ ❒ ❓ ❔ ❕ ❖ ❗ ❘ ❙ ❚ ❛ ❜ ❝ ❞ ❟'
            +'u2760: ❠ ❡ ❢ ❣ ❤ ❥ ❦ ❧ ❨ ❩ ❪ ❫ ❬ ❭ ❮ ❯ ❰ ❱ ❲ ❳ ❴ ❵ ❶ ❷ ❸ ❹ ❺ ❻ ❼ ❽ ❾ ❿'
            +'u2780: ➀ ➁ ➂ ➃ ➄ ➅ ➆ ➇ ➈ ➉ ➊ ➋ ➌ ➍ ➎ ➏ ➐ ➑ ➒ ➓ ➔ ➕ ➖ ➗ ➘ ➙ ➚ ➛ ➜ ➝ ➞ ➟'
            +'u27A0: ➠ ➡ ➢ ➣ ➤ ➥ ➦ ➧ ➨ ➩ ➪ ➫ ➬ ➭ ➮ ➯ ➰ ➱ ➲ ➳ ➴ ➵ ➶ ➷ ➸ ➹ ➺ ➻ ➼ ➽ ➾ ➿'
            +'u27C0: ⟀ ⟁ ⟂ ⟃ ⟄ ⟅ ⟆ ⟇ ⟈ ⟉ ⟊ ⟋ ⟌ ⟍ ⟎ ⟏ ⟐ ⟑ ⟒ ⟓ ⟔ ⟕ ⟖ ⟗ ⟘ ⟙ ⟚ ⟛ ⟜ ⟝ ⟞ ⟟'
            +'u27E0: ⟠ ⟡ ⟢ ⟣ ⟤ ⟥ ⟦ ⟧ ⟨ ⟩ ⟪ ⟫ ⟬ ⟭ ⟮ ⟯ ⟰ ⟱ ⟲ ⟳ ⟴ ⟵ ⟶ ⟷ ⟸ ⟹ ⟺ ⟻ ⟼ ⟽ ⟾ ⟿'
            +'u2800: ⠀ ⠁ ⠂ ⠃ ⠄ ⠅ ⠆ ⠇ ⠈ ⠉ ⠊ ⠋ ⠌ ⠍ ⠎ ⠏ ⠐ ⠑ ⠒ ⠓ ⠔ ⠕ ⠖ ⠗ ⠘ ⠙ ⠚ ⠛ ⠜ ⠝ ⠞ ⠟'
            +'u2820: ⠠ ⠡ ⠢ ⠣ ⠤ ⠥ ⠦ ⠧ ⠨ ⠩ ⠪ ⠫ ⠬ ⠭ ⠮ ⠯ ⠰ ⠱ ⠲ ⠳ ⠴ ⠵ ⠶ ⠷ ⠸ ⠹ ⠺ ⠻ ⠼ ⠽ ⠾ ⠿'
            +'u2840: ⡀ ⡁ ⡂ ⡃ ⡄ ⡅ ⡆ ⡇ ⡈ ⡉ ⡊ ⡋ ⡌ ⡍ ⡎ ⡏ ⡐ ⡑ ⡒ ⡓ ⡔ ⡕ ⡖ ⡗ ⡘ ⡙ ⡚ ⡛ ⡜ ⡝ ⡞ ⡟'
            +'u2860: ⡠ ⡡ ⡢ ⡣ ⡤ ⡥ ⡦ ⡧ ⡨ ⡩ ⡪ ⡫ ⡬ ⡭ ⡮ ⡯ ⡰ ⡱ ⡲ ⡳ ⡴ ⡵ ⡶ ⡷ ⡸ ⡹ ⡺ ⡻ ⡼ ⡽ ⡾ ⡿'
            +'u2880: ⢀ ⢁ ⢂ ⢃ ⢄ ⢅ ⢆ ⢇ ⢈ ⢉ ⢊ ⢋ ⢌ ⢍ ⢎ ⢏ ⢐ ⢑ ⢒ ⢓ ⢔ ⢕ ⢖ ⢗ ⢘ ⢙ ⢚ ⢛ ⢜ ⢝ ⢞ ⢟'
            +'u28A0: ⢠ ⢡ ⢢ ⢣ ⢤ ⢥ ⢦ ⢧ ⢨ ⢩ ⢪ ⢫ ⢬ ⢭ ⢮ ⢯ ⢰ ⢱ ⢲ ⢳ ⢴ ⢵ ⢶ ⢷ ⢸ ⢹ ⢺ ⢻ ⢼ ⢽ ⢾ ⢿'
            +'u28C0: ⣀ ⣁ ⣂ ⣃ ⣄ ⣅ ⣆ ⣇ ⣈ ⣉ ⣊ ⣋ ⣌ ⣍ ⣎ ⣏ ⣐ ⣑ ⣒ ⣓ ⣔ ⣕ ⣖ ⣗ ⣘ ⣙ ⣚ ⣛ ⣜ ⣝ ⣞ ⣟'
            +'u28E0: ⣠ ⣡ ⣢ ⣣ ⣤ ⣥ ⣦ ⣧ ⣨ ⣩ ⣪ ⣫ ⣬ ⣭ ⣮ ⣯ ⣰ ⣱ ⣲ ⣳ ⣴ ⣵ ⣶ ⣷ ⣸ ⣹ ⣺ ⣻ ⣼ ⣽ ⣾ ⣿'
            +'u2900: ⤀ ⤁ ⤂ ⤃ ⤄ ⤅ ⤆ ⤇ ⤈ ⤉ ⤊ ⤋ ⤌ ⤍ ⤎ ⤏ ⤐ ⤑ ⤒ ⤓ ⤔ ⤕ ⤖ ⤗ ⤘ ⤙ ⤚ ⤛ ⤜ ⤝ ⤞ ⤟'
            +'u2920: ⤠ ⤡ ⤢ ⤣ ⤤ ⤥ ⤦ ⤧ ⤨ ⤩ ⤪ ⤫ ⤬ ⤭ ⤮ ⤯ ⤰ ⤱ ⤲ ⤳ ⤴ ⤵ ⤶ ⤷ ⤸ ⤹ ⤺ ⤻ ⤼ ⤽ ⤾ ⤿'
            +'u2940: ⥀ ⥁ ⥂ ⥃ ⥄ ⥅ ⥆ ⥇ ⥈ ⥉ ⥊ ⥋ ⥌ ⥍ ⥎ ⥏ ⥐ ⥑ ⥒ ⥓ ⥔ ⥕ ⥖ ⥗ ⥘ ⥙ ⥚ ⥛ ⥜ ⥝ ⥞ ⥟'
            +'u2960: ⥠ ⥡ ⥢ ⥣ ⥤ ⥥ ⥦ ⥧ ⥨ ⥩ ⥪ ⥫ ⥬ ⥭ ⥮ ⥯ ⥰ ⥱ ⥲ ⥳ ⥴ ⥵ ⥶ ⥷ ⥸ ⥹ ⥺ ⥻ ⥼ ⥽ ⥾ ⥿'
            +'u2980: ⦀ ⦁ ⦂ ⦃ ⦄ ⦅ ⦆ ⦇ ⦈ ⦉ ⦊ ⦋ ⦌ ⦍ ⦎ ⦏ ⦐ ⦑ ⦒ ⦓ ⦔ ⦕ ⦖ ⦗ ⦘ ⦙ ⦚ ⦛ ⦜ ⦝ ⦞ ⦟'
            +'u29A0: ⦠ ⦡ ⦢ ⦣ ⦤ ⦥ ⦦ ⦧ ⦨ ⦩ ⦪ ⦫ ⦬ ⦭ ⦮ ⦯ ⦰ ⦱ ⦲ ⦳ ⦴ ⦵ ⦶ ⦷ ⦸ ⦹ ⦺ ⦻ ⦼ ⦽ ⦾ ⦿'
            +'u29C0: ⧀ ⧁ ⧂ ⧃ ⧄ ⧅ ⧆ ⧇ ⧈ ⧉ ⧊ ⧋ ⧌ ⧍ ⧎ ⧏ ⧐ ⧑ ⧒ ⧓ ⧔ ⧕ ⧖ ⧗ ⧘ ⧙ ⧚ ⧛ ⧜ ⧝ ⧞ ⧟'
            +'u29E0: ⧠ ⧡ ⧢ ⧣ ⧤ ⧥ ⧦ ⧧ ⧨ ⧩ ⧪ ⧫ ⧬ ⧭ ⧮ ⧯ ⧰ ⧱ ⧲ ⧳ ⧴ ⧵ ⧶ ⧷ ⧸ ⧹ ⧺ ⧻ ⧼ ⧽ ⧾ ⧿'
            +'u2A00: ⨀ ⨁ ⨂ ⨃ ⨄ ⨅ ⨆ ⨇ ⨈ ⨉ ⨊ ⨋ ⨌ ⨍ ⨎ ⨏ ⨐ ⨑ ⨒ ⨓ ⨔ ⨕ ⨖ ⨗ ⨘ ⨙ ⨚ ⨛ ⨜ ⨝ ⨞ ⨟'
            +'u2A20: ⨠ ⨡ ⨢ ⨣ ⨤ ⨥ ⨦ ⨧ ⨨ ⨩ ⨪ ⨫ ⨬ ⨭ ⨮ ⨯ ⨰ ⨱ ⨲ ⨳ ⨴ ⨵ ⨶ ⨷ ⨸ ⨹ ⨺ ⨻ ⨼ ⨽ ⨾ ⨿'
            +'u2A40: ⩀ ⩁ ⩂ ⩃ ⩄ ⩅ ⩆ ⩇ ⩈ ⩉ ⩊ ⩋ ⩌ ⩍ ⩎ ⩏ ⩐ ⩑ ⩒ ⩓ ⩔ ⩕ ⩖ ⩗ ⩘ ⩙ ⩚ ⩛ ⩜ ⩝ ⩞ ⩟'
            +'u2A60: ⩠ ⩡ ⩢ ⩣ ⩤ ⩥ ⩦ ⩧ ⩨ ⩩ ⩪ ⩫ ⩬ ⩭ ⩮ ⩯ ⩰ ⩱ ⩲ ⩳ ⩴ ⩵ ⩶ ⩷ ⩸ ⩹ ⩺ ⩻ ⩼ ⩽ ⩾ ⩿'
            +'u2A80: ⪀ ⪁ ⪂ ⪃ ⪄ ⪅ ⪆ ⪇ ⪈ ⪉ ⪊ ⪋ ⪌ ⪍ ⪎ ⪏ ⪐ ⪑ ⪒ ⪓ ⪔ ⪕ ⪖ ⪗ ⪘ ⪙ ⪚ ⪛ ⪜ ⪝ ⪞ ⪟'
            +'u2AA0: ⪠ ⪡ ⪢ ⪣ ⪤ ⪥ ⪦ ⪧ ⪨ ⪩ ⪪ ⪫ ⪬ ⪭ ⪮ ⪯ ⪰ ⪱ ⪲ ⪳ ⪴ ⪵ ⪶ ⪷ ⪸ ⪹ ⪺ ⪻ ⪼ ⪽ ⪾ ⪿';
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
   
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
           /**
* @description tests notes migration with invalid characters
* Test Case Name: Migrate note that has special characters
*/    
   
    @isTest
    static void testNotestMigrationInvalidCharacters3(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = 'u2AC0: ⫀ ⫁ ⫂ ⫃ ⫄ ⫅ ⫆ ⫇ ⫈ ⫉ ⫊ ⫋ ⫌ ⫍ ⫎ ⫏ ⫐ ⫑ ⫒ ⫓ ⫔ ⫕ ⫖ ⫗ ⫘ ⫙ ⫚ ⫛ ⫝̸ ⫝ ⫞ ⫟'
            +'u2AE0: ⫠ ⫡ ⫢ ⫣ ⫤ ⫥ ⫦ ⫧ ⫨ ⫩ ⫪ ⫫ ⫬ ⫭ ⫮ ⫯ ⫰ ⫱ ⫲ ⫳ ⫴ ⫵ ⫶ ⫷ ⫸ ⫹ ⫺ ⫻ ⫼ ⫽ ⫾ ⫿'
            +'u2B00: ⬀ ⬁ ⬂ ⬃ ⬄ ⬅ ⬆ ⬇ ⬈ ⬉ ⬊ ⬋ ⬌ ⬍ ⬎ ⬏ ⬐ ⬑ ⬒ ⬓ ⬔ ⬕ ⬖ ⬗ ⬘ ⬙ ⬚ ⬛ ⬜ ⬝ ⬞ ⬟'
            +'u2B20: ⬠ ⬡ ⬢ ⬣ ⬤ ⬥ ⬦ ⬧ ⬨ ⬩ ⬪ ⬫ ⬬ ⬭ ⬮ ⬯ ⬰ ⬱ ⬲ ⬳ ⬴ ⬵ ⬶ ⬷ ⬸ ⬹ ⬺ ⬻ ⬼ ⬽ ⬾ ⬿'
            +'u2C60: Ⱡ ⱡ Ɫ Ᵽ Ɽ ⱥ ⱦ Ⱨ ⱨ Ⱪ ⱪ Ⱬ ⱬ Ɑ Ɱ Ɐ Ɒ ⱱ Ⱳ ⱳ ⱴ Ⱶ ⱶ ⱷ ⱸ ⱹ ⱺ ⱻ ⱼ ⱽ Ȿ Ɀ'
            +'u2E80: ⺀ ⺁ ⺂ ⺃ ⺄ ⺅ ⺆ ⺇ ⺈ ⺉ ⺊ ⺋ ⺌ ⺍ ⺎ ⺏ ⺐ ⺑ ⺒ ⺓ ⺔ ⺕ ⺖ ⺗ ⺘ ⺙ ⺚ ⺛ ⺜ ⺝ ⺞ ⺟'
            +'u2EA0: ⺠ ⺡ ⺢ ⺣ ⺤ ⺥ ⺦ ⺧ ⺨ ⺩ ⺪ ⺫ ⺬ ⺭ ⺮ ⺯ ⺰ ⺱ ⺲ ⺳ ⺴ ⺵ ⺶ ⺷ ⺸ ⺹ ⺺ ⺻ ⺼ ⺽ ⺾ ⺿'
            +'u2EC0: ⻀ ⻁ ⻂ ⻃ ⻄ ⻅ ⻆ ⻇ ⻈ ⻉ ⻊ ⻋ ⻌ ⻍ ⻎ ⻏ ⻐ ⻑ ⻒ ⻓ ⻔ ⻕ ⻖ ⻗ ⻘ ⻙ ⻚ ⻛ ⻜ ⻝ ⻞ ⻟'
            +'u2EE0: ⻠ ⻡ ⻢ ⻣ ⻤ ⻥ ⻦ ⻧ ⻨ ⻩ ⻪ ⻫ ⻬ ⻭ ⻮ ⻯ ⻰ ⻱ ⻲ ⻳ ⻴ ⻵ ⻶ ⻷ ⻸ ⻹ ⻺ ⻻ ⻼ ⻽ ⻾ ⻿'
            +'u2F00: ⼀ ⼁ ⼂ ⼃ ⼄ ⼅ ⼆ ⼇ ⼈ ⼉ ⼊ ⼋ ⼌ ⼍ ⼎ ⼏ ⼐ ⼑ ⼒ ⼓ ⼔ ⼕ ⼖ ⼗ ⼘ ⼙ ⼚ ⼛ ⼜ ⼝ ⼞ ⼟'
            +'u2F20: ⼠ ⼡ ⼢ ⼣ ⼤ ⼥ ⼦ ⼧ ⼨ ⼩ ⼪ ⼫ ⼬ ⼭ ⼮ ⼯ ⼰ ⼱ ⼲ ⼳ ⼴ ⼵ ⼶ ⼷ ⼸ ⼹ ⼺ ⼻ ⼼ ⼽ ⼾ ⼿'
            +'u2F40: ⽀ ⽁ ⽂ ⽃ ⽄ ⽅ ⽆ ⽇ ⽈ ⽉ ⽊ ⽋ ⽌ ⽍ ⽎ ⽏ ⽐ ⽑ ⽒ ⽓ ⽔ ⽕ ⽖ ⽗ ⽘ ⽙ ⽚ ⽛ ⽜ ⽝ ⽞ ⽟'
            +'u3040: ぀ ぁ あ ぃ い ぅ う ぇ え ぉ お か が き ぎ く ぐ け げ こ ご さ ざ し じ す ず せ ぜ そ ぞ た'
            +'u3060: だ ち ぢ っ つ づ て で と ど な に ぬ ね の は ば ぱ ひ び ぴ ふ ぶ ぷ へ べ ぺ ほ ぼ ぽ ま み'
            +'u3360: ㍠ ㍡ ㍢ ㍣ ㍤ ㍥ ㍦ ㍧ ㍨ ㍩ ㍪ ㍫ ㍬ ㍭ ㍮ ㍯ ㍰ ㍱ ㍲ ㍳ ㍴ ㍵ ㍶ ㍷ ㍸ ㍹ ㍺ ㍻ ㍼ ㍽ ㍾ ㍿'
            +'u3380: ㎀ ㎁ ㎂ ㎃ ㎄ ㎅ ㎆ ㎇ ㎈ ㎉ ㎊ ㎋ ㎌ ㎍ ㎎ ㎏ ㎐ ㎑ ㎒ ㎓ ㎔ ㎕ ㎖ ㎗ ㎘ ㎙ ㎚ ㎛ ㎜ ㎝ ㎞ ㎟'
            +'u33A0: ㎠ ㎡ ㎢ ㎣ ㎤ ㎥ ㎦ ㎧ ㎨ ㎩ ㎪ ㎫ ㎬ ㎭ ㎮ ㎯ ㎰ ㎱ ㎲ ㎳ ㎴ ㎵ ㎶ ㎷ ㎸ ㎹ ㎺ ㎻ ㎼ ㎽ ㎾ ㎿'
            +'u33C0: ㏀ ㏁ ㏂ ㏃ ㏄ ㏅ ㏆ ㏇ ㏈ ㏉ ㏊ ㏋ ㏌ ㏍ ㏎ ㏏ ㏐ ㏑ ㏒ ㏓ ㏔ ㏕ ㏖ ㏗ ㏘ ㏙ ㏚ ㏛ ㏜ ㏝ ㏞ ㏟'
            +'u50C0: 僀 僁 僂 僃 僄 僅 僆 僇 僈 僉 僊 僋 僌 働 僎 像 僐 僑 僒 僓 僔 僕 僖 僗 僘 僙 僚 僛 僜 僝 僞 僟'
            +'u50E0: 僠 僡 僢 僣 僤 僥 僦 僧 僨 僩 僪 僫 僬 僭 僮 僯 僰 僱 僲 僳 僴 僵 僶 僷 僸 價 僺 僻 僼 僽 僾 僿'
            +'uA9E0: ꧠ ꧡ ꧢ ꧣ ꧤ ꧥ ꧦ ꧧ ꧨ ꧩ ꧪ ꧫ ꧬ ꧭ ꧮ ꧯ ꧰ ꧱ ꧲ ꧳ ꧴ ꧵ ꧶ ꧷ ꧸ ꧹ ꧺ ꧻ ꧼ ꧽ ꧾ ꧿'
            +'uAC00: 가 각 갂 갃 간 갅 갆 갇 갈 갉 갊 갋 갌 갍 갎 갏 감 갑 값 갓 갔 강 갖 갗 갘 같 갚 갛 개 객 갞 갟'
            +'uAC20: 갠 갡 갢 갣 갤 갥 갦 갧 갨 갩 갪 갫 갬 갭 갮 갯 갰 갱 갲 갳 갴 갵 갶 갷 갸 갹 갺 갻 갼 갽 갾 갿'
            +'uE220:                                '
            +'uE240:                                '
            +'uEA00:                                ';
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
   
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
        /**
* @description tests notes migration with invalid characters
* Test Case Name: Migrate note that has special characters
*/    
   
    @isTest
    static void testNotestMigrationInvalidCharacters4(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = 'uEA20:                                '
            +'uEDA0:                                '
            +'uEE20:                                '
            +'uEE60:                                '
            +'uFB00: ﬀ ﬁ ﬂ ﬃ ﬄ ﬅ ﬆ ﬇ ﬈ ﬉ ﬊ ﬋ ﬌ ﬍ ﬎ ﬏ ﬐ ﬑ ﬒ ﬓ ﬔ ﬕ ﬖ ﬗ ﬘ ﬙ ﬚ ﬛ ﬜ יִ ﬞ ײַ'
            +'uFB20: ﬠ ﬡ ﬢ ﬣ ﬤ ﬥ ﬦ ﬧ ﬨ ﬩ שׁ שׂ שּׁ שּׂ אַ אָ אּ בּ גּ דּ הּ וּ זּ ﬷ טּ יּ ךּ כּ לּ ﬽ מּ ﬿'
            +'uFFE0: ￠ ￡ ￢ ￣ ￤ ￥ ￦ ￧ ￨ ￩ ￪ ￫ ￬ ￭ ￮ ￯ ￰ ￱ ￲ ￳ ￴ ￵ ￶ ￷ ￸   ￻ ￼ �  '
            +'   藍              ☺️  珞 '
           +'樂          蘿         襤      螺 ' 
           +' ☹️                   裸 洛 濫蠟 ' 
            +' 鸞 嵐 拉 邏        烙          ';
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
   
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        //System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        //System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }


    /**
* @description tests notes migration with empty body
* Test Case Name: Migrate note with empty body
*/
    @isTest
    static void testNotestMigrationEmptyBody(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact 
* - create a legacy note with empty body
* - get the id
* - run the migration by Id
* - assert 1 contentVersion is created
* - assert 1 CDL is created
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = '';
        
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.IsPrivate = false;
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);
        
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
    /**
* @description tests notes migration with all characters body
* Test Case Name: Migrate note with all characters body
*/
    @isTest
    static void testNotestMigrationAllCharactersBody(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact 
* - create a legacy note with all characters body
* - get the id
* - run the migration by Id
* - assert 1 contentVersion is created
* - assert 1 CDL is created
*/
        
        StaticResource allCharacters = [Select body, name from StaticResource where Name = 'NMTcharacters' LIMIT 1];
        String bodys = EncodingUtil.base64Encode(allCharacters.Body);
        Integer quantity = bodys.length()/32000;
        
        Contact c = NMTTestNoteUtils.createContact();
        List<String> resultAux = new List<String>();
        for(integer i = 0; i<quantity; i++){
            //create a legacy note
            Note legacynote = new Note();
            legacynote.Title='noteTitle';
            String body = bodys.substring(i*32000, i*32000+32000);
            
            legacynote.body=body;
            legacynote.parentId=c.Id; 
            legacynote.IsPrivate = false;
            legacynote.OwnerId = UserInfo.getUserId();
            legacynote.CreatedDate = Date.today();
            
            insert legacynote;
            //get the ids
            resultAux.add(legacynote.Id);
        }
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert contentVersions were created
        System.assertEquals(quantity, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert CDLs were created
        System.assertEquals(quantity, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
    /**
* @description tests notes migration with the longest body
* Test Case Name: Migrate note with the longest body possible
*/
    @isTest
    static void testNotestMigrationLongestBody(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact 
* - create a legacy note with empty body
* - get the id
* - run the migration by Id
* - assert 1 contentVersion is created
* - assert 1 CDL is created
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = '';
        
        for(integer i=0; i<32000; i++){
            body+='a';
        }
        
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.IsPrivate = false;
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);
        
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
        }
    }
    
    
    /**
* @description tests notes migration with html in body
*/
    @isTest
    static void testNotestMigrationHtmlBody(){
if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){        
        /*
* Steps:
* - create a contact 
* - create a legacy note with html in body
* - get the id
* - run the migration by Id
* - assert 1 contentVersion is created
* - assert 1 CDL is created
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create a legacy note
        Note legacynote = new Note();
        legacynote.Title='noteTitle';
        String body = '<p><em>algo</em></p>';
        
        legacynote.body=body;
        legacynote.parentId=c.Id; 
        legacynote.IsPrivate = false;
        legacynote.OwnerId = UserInfo.getUserId();
        legacynote.CreatedDate = Date.today();
        
        insert legacynote;
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(legacynote.Id);
        
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c in :resultAux];
        //assert 1 contentVersion was created
        System.assertEquals(1, contentVersions.size(), '1 Content Note created');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 1 CDL was created
        System.assertEquals(1, cdls.size(), '1 Content Note linked to the parent Contact');
}
    }
    
    /**
* @description tests notes migration by Ids for Standard User
* Test Case Name: Migrate one object with legacy notes from standard user
*/
    @isTest
    static void testNotestMigrationByIdFromStandardUser(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact from a standard user
* - create two legacy note from a standard user
* - get the ids
* - run the migration by Ids
* - assert 2 contentVersions were created
* - assert 2 CDLs were created
*/
        
        //create two legacy note from a standard user
        
        // Setup test data
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id, ManagerId = UserInfo.getUserId(),
                          TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@notes.attachments.testorg.com');
        
        System.runAs(u) {
            // The following code runs as user 'u'
            Contact contact1 = NMTTestNoteUtils.createContact();
            Boolean privateNotes = false;
            String noteTitle = 'random note title '+NMTTestNoteUtils.randomInteger();
            NMTTestNoteUtils.createNoteForObject(2, contact1.Id, privateNotes, noteTitle);
        }
        
        // This code runs as the system user
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        List<Note> notes = [SELECT Id, Title, Body, Parent.Type, OwnerId, LastModifiedDate, CreatedDate, CreatedById, LastModifiedById FROM Note];
        //Assert that a note was created
        System.assertEquals(2, notes.size());
        
        List<String> resultAux = new List<String>();
        //get the ids
        for(Note note:notes)
        {
            resultAux.add(note.Id);
        }
        
        //assert that 2 Legacy Notes were created
        System.assertEquals(2, resultAux.size(), '2 Legacy Notes created to migrate');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 2 CDLs were created
        System.assertEquals(2, cdls.size(), '2 Content Notes linked to the parent Contact');
        }
    }
    
    /**
* @description tests notes migration by Ids for Standard User
* Test Case Name: Migrate inactive user notes
*/
    @isTest
    static void testNotestMigrationByIdFromInactiveUser(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a contact from a standard user
* - create two legacy note from a standard user
* - get the ids
* - make the user inactive
* - run the migration by Ids
* - assert 2 contentVersions were created
* - assert 2 CDLs were created
*/
        
        //create two legacy note from a standard user
        
        // Setup test data
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id, ManagerId = UserInfo.getUserId(),
                          TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@notes.attachments.testorg.com');
        
        System.runAs(u) {
            // The following code runs as user 'u'
            Contact contact1 = NMTTestNoteUtils.createContact();
            Boolean privateNotes = false;
            String noteTitle = 'random note title '+NMTTestNoteUtils.randomInteger();
            NMTTestNoteUtils.createNoteForObject(2, contact1.Id, privateNotes, noteTitle);
        }
        
        //make the user inactive
        u.IsActive = false;
        
        // This code runs as the system user
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        List<Note> notes = [SELECT Id, Title, Body, Parent.Type, OwnerId, LastModifiedDate, CreatedDate, CreatedById, LastModifiedById FROM Note];
        //Assert that a note was created
        System.assertEquals(2, notes.size());
        
        List<String> resultAux = new List<String>();
        //get the ids
        for(Note note:notes)
        {
            resultAux.add(note.Id);
        }
        
        //assert that 2 Legacy Notes were created
        System.assertEquals(2, resultAux.size(), '2 Legacy Notes created to migrate');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert 2 CDLs were created
        System.assertEquals(2, cdls.size(), '2 Content Notes linked to the parent Contact');
        }
    }
    
    
    /**
* @description tests notes migration by Object Ids from standard user
* Test Case Name: Migrate one object with legacy notes from standard user
*/
    @isTest
    static void testNotestMigrationByObjectIdFromStandardUser(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a Contact from standard user
* - create a Product from standard user
* - create two legacy note per owner from standard user
* - get the ids of the product and the contact
* - run the migration by Objects Ids
* - assert 4 contentVersions were created
* - assert 2 CDLs were created for each object
*/
        
        // Setup test data
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = prof.Id, ManagerId = UserInfo.getUserId(),
                          TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@notes.attachments.testorg.com');
        
        System.runAs(u) {
            // The following code runs as user 'u'
            Contact c = NMTTestNoteUtils.createContact();
            Product2 p = NMTTestNoteUtils.createProduct();
            //create two legacy notes for the Contact
            NMTTestNoteUtils.createNoteForObject(2, c.Id, false);
            //create two legacy notes for the Product
            NMTTestNoteUtils.createNoteForObject(2, p.Id, false);
        }
        
        // This code runs as the system user
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 LIMIT 1];
        
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add(c.Id);
        resultAux.add(p.Id);
        
        
        //assert that 2 Objects were created
        System.assertEquals(2, resultAux.size(), '2 Objects created to migrate their notes');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byObjectId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId in :resultAux
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        //assert 2 CDLs were created
        System.assertEquals(4, cdls.size(), '4 Content Notes linked to the parents ');
        }
    }
    
    /**
* @description tests notes migration by Object Names from standard user
* Test Case Name: Migrate one object with legacy notes from standard user
*/
    @isTest
    static void testNotestMigrationByObjectNameFromStandardUser(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a Contact
* - create a Product 
* - create 100 legacy note per Contact
* - create 5 legacy note per Product
* - run the migration by Objects Names and 50 as quantity
* - rerun the migration by Objects Names and 5 as quantity
* - assert 60 contentVersions were created
* - assert 60 CDLs were created (55 for Contact and 5 for Product)
* - assert NotesPendingToConvert = 45
*/
        
        // Setup test data
        // This code runs as the system user
        Profile prof = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = prof.Id, ManagerId = UserInfo.getUserId(),
                          TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@notes.attachments.testorg.com');
        
        System.runAs(u) {
            // The following code runs as user 'u'
            Contact c = NMTTestNoteUtils.createContact();
            Product2 p = NMTTestNoteUtils.createProduct();
            //create 100 legacy notes for the Contact
            NMTTestNoteUtils.createNoteForObject(100, c.Id, false);
            //create 5 legacy notes for the Product
            NMTTestNoteUtils.createNoteForObject(5, p.Id, false);
        }
        
        // This code runs as the system user
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Product2 p = [SELECT Id FROM Product2 LIMIT 1];
        
        
        Test.startTest();
        //run the migration by Objects Type	
        NMTMigratorBatch batch = new NMTMigratorBatch('Contact', null, 'byObject',50, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        NMTMigratorBatch batch2 = new NMTMigratorBatch('Product2', null, 'byObject',50, System.today(), System.today(), true);
        Id batchId2 = Database.executeBatch(batch2, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId2,'Convertion');
        NMTMigratorBatch batch3 = new NMTMigratorBatch('Contact', null, 'byObject',5, System.today(), System.today(), true);
        Id batchId3 = Database.executeBatch(batch3, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId3,'Convertion');
        NMTMigratorBatch batch4 = new NMTMigratorBatch('Product2', null, 'byObject',5, System.today(), System.today(), true);
        Id batchId4 = Database.executeBatch(batch4, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId4,'Convertion');
        Test.stopTest();
        
        
        
        List<ContentDocumentLink> cdlsContact = [SELECT Id FROM ContentDocumentLink WHERE
                                                 linkedEntityId = :c.Id
                                                 AND
                                                 contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        List<ContentDocumentLink> cdlsProduct = [SELECT Id FROM ContentDocumentLink WHERE
                                                 linkedEntityId = :p.Id
                                                 AND
                                                 contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        
        //assert 60 CDLs were created (55 for Contact and 5 for Product)
        System.assertEquals(55, cdlsContact.size(), '55 Content Notes linked to the Contact ');
        System.assertEquals(5, cdlsProduct.size(), '5 Content Notes linked to the Product ');
        
        NAMNoteConversionStatus__c conversionStatus = NMTNoteConversionStatus.find().get(0);
        }
    }
    
    /**
* @description tests notes migration by Object Ids with only private notes
* Test Case Name: Migrate by record id from standard record that only has private notes
*/
    /*
@isTest
static void testNotestMigrationByObjectIdOnlyPrivate(){

/*
* Steps:
* - create a Contact
* - create a Product 
* - create two legacy note per owner privates
* - get the ids of the product and the contact
* - run the migration by Objects Ids
* - assert no CDLs were created for each object


Contact c = NMTTestNoteUtils.createContact();
Product2 p = NMTTestNoteUtils.createProduct();
//create two legacy notes for the Contact
NMTTestNoteUtils.createNoteForObject(2, c.Id, true);
//create two legacy notes for the Product
NMTTestNoteUtils.createNoteForObject(2, p.Id, true);
List<String> resultAux = new List<String>();
//get the ids
resultAux.add(c.Id);
resultAux.add(p.Id);


//assert that 2 Objects were created
System.assertEquals(2, resultAux.size(), '2 Objects created to migrate their notes');

Test.startTest();
//run the migration by Ids	
NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byObjectId', null, System.today(), System.today());
Id batchId = Database.executeBatch(batch, 100);
NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
Test.stopTest();


List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
linkedEntityId in :resultAux
AND
contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
//assert no CDLs were created
System.assert(cdls.isEmpty());
}
*/
    
    /**
* @description tests notes migration by Object Ids with public and private notes
* Test Case Name: Migrate by record id from standard record that has public/private notes
*/
    /*
@isTest
static void testNotestMigrationByObjectIdPublicPrivate(){

/*
* Steps:
* - create a Contact
* - create two legacy notes (one private and one public)
* - get the id of the contact
* - run the migration by Objects Ids
* - assert one CDLs was created


Contact c = NMTTestNoteUtils.createContact();
//create a private legacy notes for the Contact
NMTTestNoteUtils.createNoteForObject(1, c.Id, true);
//create a public legacy notes for the Contact
NMTTestNoteUtils.createNoteForObject(1, c.Id, false);

List<String> resultAux = new List<String>();
//get the ids
resultAux.add(c.Id);


//assert that 1 Object was created
System.assertEquals(1, resultAux.size(), '1 Objects created to migrate their notes');

Test.startTest();
//run the migration by Ids	
NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byObjectId', null, System.today(), System.today());
Id batchId = Database.executeBatch(batch, 100);
NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
Test.stopTest();


List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
linkedEntityId in :resultAux
AND
contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
//assert no CDLs were created
System.assertEquals(1, cdls.size());
}

*/
    /**
* @description tests notes migration by Ids private
* Test Case Name: Migrate by note id from standard note that it's private
*/
    /*
@isTest
static void testNotestMigrationByIdPrivate(){

/*
* Steps:
* - create a contact 
* - create two legacy notes private
* - get the ids
* - run the migration by Ids
* - assert 0 CDLs were created


Contact c = NMTTestNoteUtils.createContact();
//create two legacy note
List<Note> notes = NMTTestNoteUtils.createNoteForObject(2, c.Id, true);
List<String> resultAux = new List<String>();
//get the ids
for(Note note:notes)
{
resultAux.add(note.Id);
}

//assert that 2 Legacy Notes were created
System.assertEquals(2, resultAux.size(), '2 Legacy Notes created to migrate');

Test.startTest();
//run the migration by Ids	
NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today());
Id batchId = Database.executeBatch(batch, 100);
NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
Test.stopTest();

List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
linkedEntityId = :c.Id
AND
contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
//assert no CDLs were created
System.assert(cdls.isEmpty());
}
*/
    
    
    
    /**
* @description tests notes migration by Ids that not exists
* Test Case Name: Migrate by id that not exist
*/
    @isTest
    static void testNotestMigrationByIdNotExists(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - run the migration by Ids
* - assert 0 CDLs were created
*/
        Contact c = NMTTestNoteUtils.createContact();
        List<String> resultAux = new List<String>();
        //get the ids
        resultAux.add('aa');
        
        Test.startTest();
        //run the migration by Ids	
        NMTMigratorBatch batch = new NMTMigratorBatch(null, resultAux, 'byId', null, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE
                                          linkedEntityId = :c.Id
                                          AND
                                          contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :resultAux];
        //assert no CDLs were created
        System.assert(cdls.isEmpty());
        }
    }
    
    /**
* @description tests notes migration by Object Names with negative quantity
* Test Case Name: Test limit values (max, min) at quantity input
*/
    @isTest
    static void testNotestMigrationByObjectNameNegative(){
        if(NAMUtils.isEnhancedNotesEnabled()||NAMUtils.ENABLE_NOTES_TESTS){
        /*
* Steps:
* - create a Contact
* - create 100 legacy note per Contact
* - run the migration by Objects Names and -10 as quantity
* - assert no contentVersions were created
* - assert NotesPendingToConvert = 100
*/
        
        Contact c = NMTTestNoteUtils.createContact();
        //create two legacy notes for the Contact
        NMTTestNoteUtils.createNoteForObject(100, c.Id, false);
        
        Test.startTest();
        //run the migration by Objects Type	
        NMTMigratorBatch batch = new NMTMigratorBatch('Contact', null, 'byObject',-10, System.today(), System.today(), true);
        Id batchId = Database.executeBatch(batch, 100);
        NMTNoteConversionStatus.changeStatus('Progress', batchId,'Convertion');
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE LegacyNoteConvertedId__c != null];
        //assert no contentVersion were created
        System.assert(contentVersions.isEmpty());
        
        List<ContentDocumentLink> cdlsContact = [SELECT Id FROM ContentDocumentLink WHERE
                                                 linkedEntityId = :c.Id
                                                 AND
                                                 contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c != null];
        
        //assert no CDLs were created 
        System.assert(cdlsContact.isEmpty());
        
        NAMNoteConversionStatus__c conversionStatus = NMTNoteConversionStatus.find().get(0);
        }
    }
}