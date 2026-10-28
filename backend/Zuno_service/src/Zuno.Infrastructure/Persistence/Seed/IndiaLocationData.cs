namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// Baseline India State -> District reference data (28 states + 8 union territories).
/// Best-effort from general knowledge as of this writing; district boundaries/names occasionally
/// change (splits, renames), so treat this as a strong starting point rather than a guaranteed-exact
/// source of truth. Individual rows can be corrected later via a normal migration.
/// </summary>
public static class IndiaLocationData
{
    public static readonly IReadOnlyDictionary<string, string[]> StatesAndDistricts = new Dictionary<string, string[]>
    {
        ["Andhra Pradesh"] =
        [
            "Srikakulam", "Parvathipuram Manyam", "Vizianagaram", "Visakhapatnam", "Alluri Sitharama Raju",
            "Anakapalli", "Kakinada", "East Godavari", "Konaseema", "West Godavari", "Eluru", "Krishna",
            "NTR", "Guntur", "Palnadu", "Bapatla", "Prakasam", "Nellore", "Kurnool", "Nandyal", "Anantapur",
            "Sri Sathya Sai", "YSR Kadapa", "Annamayya", "Chittoor", "Tirupati",
        ],
        ["Arunachal Pradesh"] =
        [
            "Tawang", "West Kameng", "East Kameng", "Papum Pare", "Kurung Kumey", "Kra Daadi",
            "Lower Subansiri", "Upper Subansiri", "West Siang", "Lepa Rada", "East Siang", "Siang",
            "Upper Siang", "Lower Siang", "Lower Dibang Valley", "Dibang Valley", "Anjaw", "Lohit",
            "Namsai", "Changlang", "Tirap", "Longding", "Kamle", "Shi Yomi", "Pakke-Kessang",
        ],
        ["Assam"] =
        [
            "Kokrajhar", "Bongaigaon", "Goalpara", "Barpeta", "Nalbari", "Baksa", "Chirang", "Kamrup",
            "Kamrup Metropolitan", "Darrang", "Udalguri", "Morigaon", "Nagaon", "Hojai", "Sonitpur",
            "Biswanath", "Lakhimpur", "Dhemaji", "Majuli", "Golaghat", "Jorhat", "Sivasagar", "Charaideo",
            "Dibrugarh", "Tinsukia", "Karbi Anglong", "West Karbi Anglong", "Dima Hasao", "Cachar",
            "Karimganj", "Hailakandi", "South Salmara-Mankachar", "Bajali", "Tamulpur", "Dhubri",
        ],
        ["Bihar"] =
        [
            "Patna", "Nalanda", "Bhojpur", "Buxar", "Rohtas", "Kaimur", "Aurangabad", "Gaya", "Jehanabad",
            "Arwal", "Nawada", "Jamui", "Lakhisarai", "Sheikhpura", "Munger", "Begusarai", "Khagaria",
            "Bhagalpur", "Banka", "Saharsa", "Supaul", "Madhepura", "Purnia", "Katihar", "Araria",
            "Kishanganj", "Darbhanga", "Madhubani", "Samastipur", "Muzaffarpur", "Sitamarhi", "Sheohar",
            "Vaishali", "East Champaran", "West Champaran", "Gopalganj", "Siwan", "Saran",
        ],
        ["Chhattisgarh"] =
        [
            "Raipur", "Balodabazar", "Mahasamund", "Dhamtari", "Gariaband", "Bilaspur", "Mungeli",
            "Raigarh", "Janjgir-Champa", "Korba", "Sarangarh-Bilaigarh", "Jashpur", "Surguja",
            "Balrampur", "Surajpur", "Koriya", "Durg", "Bemetara", "Kabirdham", "Rajnandgaon", "Balod",
            "Bastar", "Kondagaon", "Narayanpur", "Dantewada", "Sukma", "Bijapur", "Kanker",
            "Mohla-Manpur-Ambagarh Chowki", "Khairagarh-Chhuikhadan-Gandai",
            "Manendragarh-Chirmiri-Bharatpur", "Gaurela-Pendra-Marwahi", "Sakti",
        ],
        ["Goa"] = ["North Goa", "South Goa"],
        ["Gujarat"] =
        [
            "Ahmedabad", "Gandhinagar", "Mehsana", "Patan", "Banaskantha", "Sabarkantha", "Aravalli",
            "Kheda", "Anand", "Vadodara", "Chhota Udaipur", "Panchmahal", "Dahod", "Mahisagar", "Surat",
            "Navsari", "Valsad", "Dang", "Tapi", "Bharuch", "Narmada", "Rajkot", "Jamnagar",
            "Devbhoomi Dwarka", "Porbandar", "Junagadh", "Gir Somnath", "Amreli", "Bhavnagar", "Botad",
            "Surendranagar", "Kutch", "Morbi",
        ],
        ["Haryana"] =
        [
            "Ambala", "Panchkula", "Yamunanagar", "Kurukshetra", "Kaithal", "Karnal", "Panipat",
            "Sonipat", "Jind", "Fatehabad", "Sirsa", "Hisar", "Bhiwani", "Charkhi Dadri", "Rohtak",
            "Jhajjar", "Mahendragarh", "Rewari", "Gurugram", "Nuh", "Faridabad", "Palwal",
        ],
        ["Himachal Pradesh"] =
        [
            "Chamba", "Kangra", "Una", "Hamirpur", "Bilaspur", "Mandi", "Kullu", "Lahaul and Spiti",
            "Kinnaur", "Shimla", "Solan", "Sirmaur",
        ],
        ["Jharkhand"] =
        [
            "Garhwa", "Palamu", "Latehar", "Chatra", "Hazaribagh", "Koderma", "Giridih", "Bokaro",
            "Dhanbad", "Ramgarh", "Ranchi", "Khunti", "Gumla", "Simdega", "Lohardaga", "West Singhbhum",
            "East Singhbhum", "Seraikela-Kharsawan", "Jamtara", "Deoghar", "Dumka", "Pakur", "Godda",
            "Sahibganj",
        ],
        ["Karnataka"] =
        [
            "Bagalkot", "Ballari", "Belagavi", "Bengaluru Urban", "Bengaluru Rural", "Bidar",
            "Chamarajanagar", "Chikballapur", "Chikkamagaluru", "Chitradurga", "Dakshina Kannada",
            "Davanagere", "Dharwad", "Gadag", "Kalaburagi", "Hassan", "Haveri", "Kodagu", "Kolar",
            "Koppal", "Mandya", "Mysuru", "Raichur", "Ramanagara", "Shivamogga", "Tumakuru", "Udupi",
            "Uttara Kannada", "Vijayapura", "Yadgir", "Vijayanagara",
        ],
        ["Kerala"] =
        [
            "Thiruvananthapuram", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki",
            "Ernakulam", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur",
            "Kasaragod",
        ],
        ["Madhya Pradesh"] =
        [
            "Bhopal", "Sehore", "Raisen", "Vidisha", "Rajgarh", "Indore", "Dhar", "Jhabua", "Alirajpur",
            "Khargone", "Barwani", "Khandwa", "Burhanpur", "Ujjain", "Dewas", "Shajapur", "Agar Malwa",
            "Ratlam", "Mandsaur", "Neemuch", "Gwalior", "Datia", "Shivpuri", "Ashoknagar", "Guna",
            "Morena", "Bhind", "Sheopur", "Jabalpur", "Katni", "Narsinghpur", "Chhindwara", "Seoni",
            "Mandla", "Dindori", "Balaghat", "Sagar", "Damoh", "Panna", "Chhatarpur", "Tikamgarh",
            "Niwari", "Satna", "Rewa", "Sidhi", "Singrauli", "Shahdol", "Umaria", "Anuppur", "Betul",
            "Harda", "Narmadapuram", "Pandhurna", "Maihar",
        ],
        ["Maharashtra"] =
        [
            "Mumbai City", "Mumbai Suburban", "Thane", "Palghar", "Raigad", "Ratnagiri", "Sindhudurg",
            "Pune", "Satara", "Sangli", "Solapur", "Kolhapur", "Nashik", "Dhule", "Nandurbar", "Jalgaon",
            "Ahmednagar", "Chhatrapati Sambhajinagar", "Jalna", "Beed", "Latur", "Dharashiv", "Nanded",
            "Parbhani", "Hingoli", "Akola", "Amravati", "Buldhana", "Washim", "Yavatmal", "Nagpur",
            "Wardha", "Chandrapur", "Gadchiroli", "Gondia", "Bhandara",
        ],
        ["Manipur"] =
        [
            "Imphal East", "Imphal West", "Bishnupur", "Thoubal", "Kakching", "Kangpokpi", "Senapati",
            "Tamenglong", "Noney", "Churachandpur", "Pherzawl", "Chandel", "Ukhrul", "Jiribam",
            "Tengnoupal", "Kamjong",
        ],
        ["Meghalaya"] =
        [
            "East Khasi Hills", "West Khasi Hills", "South West Khasi Hills", "Ri Bhoi",
            "East Jaintia Hills", "West Jaintia Hills", "East Garo Hills", "West Garo Hills",
            "South Garo Hills", "North Garo Hills", "South West Garo Hills", "Eastern West Khasi Hills",
        ],
        ["Mizoram"] =
        [
            "Aizawl", "Lunglei", "Champhai", "Serchhip", "Kolasib", "Mamit", "Lawngtlai", "Saiha",
            "Khawzawl", "Hnahthial", "Saitual",
        ],
        ["Nagaland"] =
        [
            "Kohima", "Dimapur", "Mokokchung", "Tuensang", "Wokha", "Zunheboto", "Phek", "Mon",
            "Longleng", "Kiphire", "Peren", "Noklak", "Chumoukedima", "Niuland", "Tseminyu", "Shamator",
        ],
        ["Odisha"] =
        [
            "Bargarh", "Jharsuguda", "Sambalpur", "Debagarh", "Sundargarh", "Kendujhar", "Mayurbhanj",
            "Balasore", "Bhadrak", "Jajpur", "Kendrapara", "Cuttack", "Jagatsinghpur", "Puri", "Khordha",
            "Nayagarh", "Ganjam", "Gajapati", "Rayagada", "Koraput", "Nabarangpur", "Malkangiri",
            "Kalahandi", "Nuapada", "Balangir", "Subarnapur", "Angul", "Dhenkanal", "Boudh",
        ],
        ["Punjab"] =
        [
            "Amritsar", "Tarn Taran", "Gurdaspur", "Pathankot", "Hoshiarpur", "Kapurthala", "Jalandhar",
            "Shahid Bhagat Singh Nagar", "Rupnagar", "Sahibzada Ajit Singh Nagar", "Fatehgarh Sahib",
            "Ludhiana", "Moga", "Ferozepur", "Fazilka", "Muktsar", "Faridkot", "Bathinda", "Mansa",
            "Sangrur", "Malerkotla", "Barnala", "Patiala",
        ],
        ["Rajasthan"] =
        [
            "Ajmer", "Alwar", "Banswara", "Baran", "Barmer", "Bharatpur", "Bhilwara", "Bikaner", "Bundi",
            "Chittorgarh", "Churu", "Dausa", "Dholpur", "Dungarpur", "Hanumangarh", "Jaipur", "Jaisalmer",
            "Jalore", "Jhalawar", "Jhunjhunu", "Jodhpur", "Karauli", "Kota", "Nagaur", "Pali",
            "Pratapgarh", "Rajsamand", "Sawai Madhopur", "Sikar", "Sirohi", "Sri Ganganagar", "Tonk",
            "Udaipur",
        ],
        ["Sikkim"] = ["Gangtok", "Pakyong", "Soreng", "Namchi", "Gyalshing", "Mangan"],
        ["Tamil Nadu"] =
        [
            "Chennai", "Tiruvallur", "Chengalpattu", "Kancheepuram", "Vellore", "Ranipet", "Tirupathur",
            "Krishnagiri", "Dharmapuri", "Salem", "Namakkal", "Erode", "Tiruppur", "Coimbatore",
            "Nilgiris", "Dindigul", "Karur", "Tiruchirappalli", "Perambalur", "Ariyalur", "Cuddalore",
            "Villupuram", "Kallakurichi", "Thanjavur", "Tiruvarur", "Nagapattinam", "Mayiladuthurai",
            "Pudukkottai", "Sivaganga", "Ramanathapuram", "Madurai", "Theni", "Virudhunagar", "Tenkasi",
            "Tirunelveli", "Thoothukudi", "Kanyakumari",
        ],
        ["Telangana"] =
        [
            "Adilabad", "Nirmal", "Nizamabad", "Kamareddy", "Jagtial", "Peddapalli", "Mancherial",
            "Rajanna Sircilla", "Karimnagar", "Jayashankar Bhupalpally", "Mulugu", "Warangal",
            "Hanamkonda", "Jangaon", "Bhadradri Kothagudem", "Khammam", "Mahabubabad", "Suryapet",
            "Nalgonda", "Yadadri Bhuvanagiri", "Medchal-Malkajgiri", "Hyderabad", "Rangareddy",
            "Vikarabad", "Sangareddy", "Medak", "Siddipet", "Mahabubnagar", "Nagarkurnool", "Wanaparthy",
            "Jogulamba Gadwal", "Narayanpet", "Komaram Bheem",
        ],
        ["Tripura"] =
        [
            "West Tripura", "Sepahijala", "Gomati", "South Tripura", "Dhalai", "Khowai", "Unakoti",
            "North Tripura",
        ],
        ["Uttar Pradesh"] =
        [
            "Agra", "Aligarh", "Prayagraj", "Ambedkar Nagar", "Amethi", "Amroha", "Auraiya", "Ayodhya",
            "Azamgarh", "Baghpat", "Bahraich", "Ballia", "Balrampur", "Banda", "Barabanki", "Bareilly",
            "Basti", "Bhadohi", "Bijnor", "Budaun", "Bulandshahr", "Chandauli", "Chitrakoot", "Deoria",
            "Etah", "Etawah", "Farrukhabad", "Fatehpur", "Firozabad", "Gautam Buddha Nagar", "Ghaziabad",
            "Ghazipur", "Gonda", "Gorakhpur", "Hamirpur", "Hapur", "Hardoi", "Hathras", "Jalaun",
            "Jaunpur", "Jhansi", "Kannauj", "Kanpur Dehat", "Kanpur Nagar", "Kasganj", "Kaushambi",
            "Lakhimpur Kheri", "Kushinagar", "Lalitpur", "Lucknow", "Maharajganj", "Mahoba", "Mainpuri",
            "Mathura", "Mau", "Meerut", "Mirzapur", "Moradabad", "Muzaffarnagar", "Pilibhit",
            "Pratapgarh", "Raebareli", "Rampur", "Saharanpur", "Sambhal", "Sant Kabir Nagar",
            "Shahjahanpur", "Shamli", "Shravasti", "Siddharthnagar", "Sitapur", "Sonbhadra", "Sultanpur",
            "Unnao", "Varanasi",
        ],
        ["Uttarakhand"] =
        [
            "Almora", "Bageshwar", "Chamoli", "Champawat", "Dehradun", "Haridwar", "Nainital",
            "Pauri Garhwal", "Pithoragarh", "Rudraprayag", "Tehri Garhwal", "Udham Singh Nagar",
            "Uttarkashi",
        ],
        ["West Bengal"] =
        [
            "Alipurduar", "Bankura", "Birbhum", "Cooch Behar", "Dakshin Dinajpur", "Darjeeling",
            "Hooghly", "Howrah", "Jalpaiguri", "Jhargram", "Kalimpong", "Kolkata", "Malda",
            "Murshidabad", "Nadia", "North 24 Parganas", "Paschim Bardhaman", "Paschim Medinipur",
            "Purba Bardhaman", "Purba Medinipur", "Purulia", "South 24 Parganas", "Uttar Dinajpur",
        ],
        ["Andaman and Nicobar Islands"] = ["Nicobar", "North and Middle Andaman", "South Andaman"],
        ["Chandigarh"] = ["Chandigarh"],
        ["Dadra and Nagar Haveli and Daman and Diu"] = ["Dadra and Nagar Haveli", "Daman", "Diu"],
        ["Delhi"] =
        [
            "Central Delhi", "East Delhi", "New Delhi", "North Delhi", "North East Delhi",
            "North West Delhi", "Shahdara", "South Delhi", "South East Delhi", "South West Delhi",
            "West Delhi",
        ],
        ["Jammu and Kashmir"] =
        [
            "Anantnag", "Bandipora", "Baramulla", "Budgam", "Doda", "Ganderbal", "Jammu", "Kathua",
            "Kishtwar", "Kulgam", "Kupwara", "Poonch", "Pulwama", "Rajouri", "Ramban", "Reasi", "Samba",
            "Shopian", "Srinagar", "Udhampur",
        ],
        ["Ladakh"] = ["Kargil", "Leh"],
        ["Lakshadweep"] = ["Lakshadweep"],
        ["Puducherry"] = ["Puducherry", "Karaikal", "Mahe", "Yanam"],
    };
}
