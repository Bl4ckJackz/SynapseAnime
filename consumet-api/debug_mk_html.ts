
import axios from 'axios';
import { load } from 'cheerio';

async function run() {
    try {
        const { data } = await axios.get('https://mangakatana.com/manga/tokyo-ghoul.3476');
        const $ = load(data);

        console.log('Searching for chapters...');
        // Try finding any table row
        const rows = $('tr').length;
        console.log(`Found ${rows} table rows.`);

        // Print classes of divs that look like chapter lists
        console.log('Divs with class "chapters":', $('.chapters').length);
        console.log('Divs with class "chapter":', $('.chapter').length);

        // Print usage of tr.uk-table-middle
        console.log('tr.uk-table-middle count:', $('tr.uk-table-middle').length);

        // Dump part of HTML if no standard selector matches
        if ($('.chapter').length > 0) {
            console.log('First chapter HTML:', $('.chapter').first().html());
            console.log('Update time count:', $('.update_time').length);
        }
    } catch (e) {
        console.error(e);
    }
}

run();
