import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import relativeTime from 'dayjs/plugin/relativeTime';
import('dayjs/locale/ar')
import('dayjs/locale/de')
import('dayjs/locale/en') 
import('dayjs/locale/es')
import('dayjs/locale/fr')
import('dayjs/locale/ja')
import('dayjs/locale/ka')
import('dayjs/locale/ko')
import('dayjs/locale/nl')
import('dayjs/locale/pl')
import('dayjs/locale/pt')
import('dayjs/locale/ru')
import('dayjs/locale/tr')
import('dayjs/locale/uk')
import('dayjs/locale/zh') 
import('dayjs/locale/zh-tw')

dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.extend(relativeTime);

export default dayjs;
