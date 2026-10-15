namespace Zuno.Infrastructure.Persistence.Seed;

/// <summary>
/// Where each district is, as a single point, for measuring roughly how far away a job is.
/// </summary>
/// <remarks>
/// <para>
/// <strong>District headquarters, not polygon centroids.</strong> Jobs happen in towns, not in the
/// geometric middle of an administrative boundary — the middle of Idukki is forest, while its
/// headquarters is where somebody would actually be hired. For this purpose the headquarters is both
/// easier to verify and the better answer.
/// </para>
/// <para>
/// <strong>South India only, deliberately.</strong> 147 rows covering the states this app operates
/// in. Curating all 765 Indian districts to a standard anyone could check is a data-entry job with no
/// verification path, and <see cref="IndiaLocationData"/> already describes its own district
/// <em>names</em> as best-effort — piling unverified coordinates on top of unverified names would
/// compound the error. A district with no entry here simply has no centroid, which costs one fallback
/// step and never rejects anything. Adding a state later is an edit to this file plus one migration.
/// </para>
/// <para>
/// <strong>A fallback, not the primary source.</strong> A centroid is used only when a post has no
/// exact pin and could not be geocoded, and the post then records that its location is approximate so
/// the app can say so. It is never used to compare two posts whose real positions are known: two jobs
/// in one district are zero apart by this measure, which would rank a job across the city as nearer
/// than one next door.
/// </para>
/// </remarks>
public static class DistrictCentroidData
{
    /// <summary>Headquarters latitude and longitude, keyed on state then district.</summary>
    public static readonly IReadOnlyDictionary<
        string,
        IReadOnlyDictionary<string, (decimal Latitude, decimal Longitude)>> ByState =
        new Dictionary<string, IReadOnlyDictionary<string, (decimal, decimal)>>
        {
            ["Kerala"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Alappuzha"] = (9.4981m, 76.3388m),
                ["Ernakulam"] = (9.9816m, 76.2999m),
                ["Idukki"] = (9.8494m, 76.9700m),
                ["Kannur"] = (11.8745m, 75.3704m),
                ["Kasaragod"] = (12.4996m, 74.9869m),
                ["Kollam"] = (8.8932m, 76.6141m),
                ["Kottayam"] = (9.5916m, 76.5222m),
                ["Kozhikode"] = (11.2588m, 75.7804m),
                ["Malappuram"] = (11.0510m, 76.0711m),
                ["Palakkad"] = (10.7867m, 76.6548m),
                ["Pathanamthitta"] = (9.2648m, 76.7870m),
                ["Thiruvananthapuram"] = (8.5241m, 76.9366m),
                ["Thrissur"] = (10.5276m, 76.2144m),
                ["Wayanad"] = (11.6054m, 76.0862m),
            },
            ["Tamil Nadu"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Ariyalur"] = (11.1401m, 79.0782m),
                ["Chengalpattu"] = (12.6819m, 79.9888m),
                ["Chennai"] = (13.0827m, 80.2707m),
                ["Coimbatore"] = (11.0168m, 76.9558m),
                ["Cuddalore"] = (11.7480m, 79.7714m),
                ["Dharmapuri"] = (12.1211m, 78.1582m),
                ["Dindigul"] = (10.3624m, 77.9695m),
                ["Erode"] = (11.3410m, 77.7172m),
                ["Kallakurichi"] = (11.7383m, 78.9597m),
                ["Kancheepuram"] = (12.8342m, 79.7036m),
                ["Kanyakumari"] = (8.1833m, 77.4119m),
                ["Karur"] = (10.9601m, 78.0766m),
                ["Krishnagiri"] = (12.5186m, 78.2137m),
                ["Madurai"] = (9.9252m, 78.1198m),
                ["Mayiladuthurai"] = (11.1018m, 79.6528m),
                ["Nagapattinam"] = (10.7672m, 79.8449m),
                ["Namakkal"] = (11.2189m, 78.1674m),
                ["Nilgiris"] = (11.4102m, 76.6950m),
                ["Perambalur"] = (11.2342m, 78.8808m),
                ["Pudukkottai"] = (10.3833m, 78.8001m),
                ["Ramanathapuram"] = (9.3639m, 78.8395m),
                ["Ranipet"] = (12.9249m, 79.3308m),
                ["Salem"] = (11.6643m, 78.1460m),
                ["Sivaganga"] = (9.8433m, 78.4809m),
                ["Tenkasi"] = (8.9594m, 77.3152m),
                ["Thanjavur"] = (10.7870m, 79.1378m),
                ["Theni"] = (10.0104m, 77.4977m),
                ["Thoothukudi"] = (8.7642m, 78.1348m),
                ["Tiruchirappalli"] = (10.7905m, 78.7047m),
                ["Tirunelveli"] = (8.7139m, 77.7567m),
                ["Tirupathur"] = (12.4951m, 78.5678m),
                ["Tiruppur"] = (11.1085m, 77.3411m),
                ["Tiruvallur"] = (13.1231m, 79.9120m),
                ["Tiruvarur"] = (10.7726m, 79.6368m),
                ["Vellore"] = (12.9165m, 79.1325m),
                ["Villupuram"] = (11.9401m, 79.4861m),
                ["Virudhunagar"] = (9.5810m, 77.9624m),
            },
            ["Karnataka"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Bagalkot"] = (16.1691m, 75.6615m),
                ["Ballari"] = (15.1394m, 76.9214m),
                ["Belagavi"] = (15.8497m, 74.4977m),
                ["Bengaluru Rural"] = (13.2437m, 77.7116m),
                ["Bengaluru Urban"] = (12.9716m, 77.5946m),
                ["Bidar"] = (17.9104m, 77.5199m),
                ["Chamarajanagar"] = (11.9261m, 76.9438m),
                ["Chikballapur"] = (13.4355m, 77.7315m),
                ["Chikkamagaluru"] = (13.3153m, 75.7754m),
                ["Chitradurga"] = (14.2251m, 76.3980m),
                ["Dakshina Kannada"] = (12.9141m, 74.8560m),
                ["Davanagere"] = (14.4644m, 75.9218m),
                ["Dharwad"] = (15.4589m, 75.0078m),
                ["Gadag"] = (15.4167m, 75.6167m),
                ["Hassan"] = (13.0072m, 76.0962m),
                ["Haveri"] = (14.7935m, 75.4044m),
                ["Kalaburagi"] = (17.3297m, 76.8343m),
                ["Kodagu"] = (12.4244m, 75.7382m),
                ["Kolar"] = (13.1357m, 78.1325m),
                ["Koppal"] = (15.3500m, 76.1546m),
                ["Mandya"] = (12.5218m, 76.8951m),
                ["Mysuru"] = (12.2958m, 76.6394m),
                ["Raichur"] = (16.2076m, 77.3463m),
                ["Ramanagara"] = (12.7209m, 77.2800m),
                ["Shivamogga"] = (13.9299m, 75.5681m),
                ["Tumakuru"] = (13.3379m, 77.1173m),
                ["Udupi"] = (13.3409m, 74.7421m),
                ["Uttara Kannada"] = (14.8137m, 74.1297m),
                ["Vijayanagara"] = (15.2695m, 76.3870m),
                ["Vijayapura"] = (16.8302m, 75.7100m),
                ["Yadgir"] = (16.7700m, 77.1376m),
            },
            ["Telangana"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Adilabad"] = (19.6640m, 78.5320m),
                ["Bhadradri Kothagudem"] = (17.5500m, 80.6200m),
                ["Hanamkonda"] = (17.9974m, 79.5600m),
                ["Hyderabad"] = (17.3850m, 78.4867m),
                ["Jagtial"] = (18.7895m, 78.9117m),
                ["Jangaon"] = (17.7200m, 79.1500m),
                ["Jayashankar Bhupalpally"] = (18.4333m, 79.8667m),
                ["Jogulamba Gadwal"] = (16.2333m, 77.8000m),
                ["Kamareddy"] = (18.3200m, 78.3400m),
                ["Karimnagar"] = (18.4386m, 79.1288m),
                ["Khammam"] = (17.2473m, 80.1514m),
                ["Komaram Bheem"] = (19.3600m, 79.2800m),
                ["Mahabubabad"] = (17.6000m, 80.0000m),
                ["Mahabubnagar"] = (16.7488m, 77.9854m),
                ["Mancherial"] = (18.8700m, 79.4400m),
                ["Medak"] = (18.0460m, 78.2640m),
                ["Medchal-Malkajgiri"] = (17.6300m, 78.4800m),
                ["Mulugu"] = (18.1900m, 79.9400m),
                ["Nagarkurnool"] = (16.4800m, 78.3200m),
                ["Nalgonda"] = (17.0575m, 79.2671m),
                ["Narayanpet"] = (16.7450m, 77.4950m),
                ["Nirmal"] = (19.0967m, 78.3428m),
                ["Nizamabad"] = (18.6725m, 78.0941m),
                ["Peddapalli"] = (18.6167m, 79.3833m),
                ["Rajanna Sircilla"] = (18.3900m, 78.8300m),
                ["Rangareddy"] = (17.2000m, 78.3000m),
                ["Sangareddy"] = (17.6250m, 78.0850m),
                ["Siddipet"] = (18.1018m, 78.8520m),
                ["Suryapet"] = (17.1400m, 79.6200m),
                ["Vikarabad"] = (17.3370m, 77.9040m),
                ["Wanaparthy"] = (16.3600m, 78.0600m),
                ["Warangal"] = (17.9689m, 79.5941m),
                ["Yadadri Bhuvanagiri"] = (17.6000m, 78.9000m),
            },
            ["Andhra Pradesh"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Alluri Sitharama Raju"] = (18.0800m, 82.6700m),
                ["Anakapalli"] = (17.6911m, 83.0037m),
                ["Anantapur"] = (14.6819m, 77.6006m),
                ["Annamayya"] = (14.0550m, 78.7500m),
                ["Bapatla"] = (15.9044m, 80.4670m),
                ["Chittoor"] = (13.2172m, 79.1003m),
                ["East Godavari"] = (17.0005m, 81.8040m),
                ["Eluru"] = (16.7107m, 81.0952m),
                ["Guntur"] = (16.3067m, 80.4365m),
                ["Kakinada"] = (16.9891m, 82.2475m),
                ["Konaseema"] = (16.5786m, 82.0060m),
                ["Krishna"] = (16.1875m, 81.1389m),
                ["Kurnool"] = (15.8281m, 78.0373m),
                ["Nandyal"] = (15.4777m, 78.4873m),
                ["Nellore"] = (14.4426m, 79.9865m),
                ["NTR"] = (16.5062m, 80.6480m),
                ["Palnadu"] = (16.2350m, 80.0490m),
                ["Parvathipuram Manyam"] = (18.7800m, 83.4300m),
                ["Prakasam"] = (15.5057m, 80.0499m),
                ["Sri Sathya Sai"] = (14.1650m, 77.8110m),
                ["Srikakulam"] = (18.2949m, 83.8938m),
                ["Tirupati"] = (13.6288m, 79.4192m),
                ["Visakhapatnam"] = (17.6868m, 83.2185m),
                ["Vizianagaram"] = (18.1067m, 83.3956m),
                ["West Godavari"] = (16.5449m, 81.5212m),
                ["YSR Kadapa"] = (14.4674m, 78.8241m),
            },
            ["Puducherry"] = new Dictionary<string, (decimal, decimal)>
            {
                ["Karaikal"] = (10.9254m, 79.8380m),
                ["Mahe"] = (11.7025m, 75.5334m),
                ["Puducherry"] = (11.9416m, 79.8083m),
                ["Yanam"] = (16.7333m, 82.2167m),
            },
            ["Goa"] = new Dictionary<string, (decimal, decimal)>
            {
                ["North Goa"] = (15.4909m, 73.8278m),
                ["South Goa"] = (15.2832m, 73.9862m),
            },
        };

    /// <summary>The district point, or null when this district is outside the curated states.</summary>
    public static (decimal Latitude, decimal Longitude)? For(string stateName, string districtName) =>
        ByState.TryGetValue(stateName, out var districts)
        && districts.TryGetValue(districtName, out var point)
            ? point
            : null;
}
