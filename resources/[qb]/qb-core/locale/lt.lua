local Translations = {
    error = {
        not_online = 'Žaidėjas neprisijungęs',
        wrong_format = 'Neteisingas formatas',
        missing_args = 'Ne visi argumentai nurodyti (x, y, z)',
        missing_args2 = 'Visi argumentai turi būti užpildyti!',
        no_access = 'Neturite prieigos prie šios komandos',
        company_too_poor = 'Jūsų darbdavys neturi lėšų',
        item_not_exist = 'Daiktas neegzistuoja',
        too_heavy = 'Inventorius per pilnas',
        location_not_exist = 'Vieta neegzistuoja',
        duplicate_license = 'Rasta dubliuota Rockstar licencija',
        no_valid_license = 'Nerasta galiojančios Rockstar licencijos',
        not_whitelisted = 'Jūs nesate įtrauktas į serverio baltąjį sąrašą',
        server_already_open = 'Serveris jau atidarytas',
        server_already_closed = 'Serveris jau uždarytas',
        no_permission = 'Neturite teisių šiam veiksmui',
        no_waypoint = 'Nepasirinktas kelio taškas',
        tp_error = 'Teleportacijos klaida',
        connecting_database_error = 'Duomenų bazės klaida jungiantis prie serverio. (Ar SQL serveris įjungtas?)',
        connecting_database_timeout = 'Baigėsi laikas jungiantis prie duomenų bazės. (Ar SQL serveris įjungtas?)',
    },
    success = {
        server_opened = 'Serveris atidarytas',
        server_closed = 'Serveris uždarytas',
        teleported_waypoint = 'Teleportuota į kelio tašką',
    },
    info = {
        received_paycheck = 'Gavote atlyginimą: $%{value}',
        job_info = 'Darbas: %{value} | Laipsnis: %{value2} | Pamaina: %{value3}',
        job_info_division = 'Darbas: %{value} | Laipsnis: %{value2} | Pamaina: %{value3} | Divizija: %{value4}',
        gang_info = 'Gauja: %{value} | Laipsnis: %{value2}',
        on_duty = 'Dabar esate pamainoje!',
        off_duty = 'Dabar nebe pamainoje!',
        checking_ban = 'Sveiki, %s. Tikriname, ar nesate užblokuotas.',
        join_server = 'Sveiki atvykę, %s, į {Server Name}.',
        checking_whitelisted = 'Sveiki, %s. Tikriname prieigos teises.',
        exploit_banned = 'Užblokuotas dėl sukčiavimo. Daugiau informacijos Discord: %{discord}',
        exploit_dropped = 'Išmestas dėl išnaudojimo (exploit)',
    },
    command = {
        tp = {
            help = 'Teleportuoti pas žaidėją arba į koordinates (tik admin)',
            params = {
                x = { name = 'id/x', help = 'Žaidėjo ID arba X koordinatė' },
                y = { name = 'y', help = 'Y koordinatė' },
                z = { name = 'z', help = 'Z koordinatė' },
            },
        },
        tpm = { help = 'Teleportuoti į kelio tašką (tik admin)' },
        togglepvp = { help = 'Įjungti / išjungti PvP serveryje (tik admin)' },
        addpermission = {
            help = 'Suteikti žaidėjui teises (tik dievas)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                permission = { name = 'permission', help = 'Teisių lygis' },
            },
        },
        removepermission = {
            help = 'Pašalinti žaidėjo teises (tik dievas)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                permission = { name = 'permission', help = 'Teisių lygis' },
            },
        },
        openserver = { help = 'Atidaryti serverį visiems (tik admin)' },
        closeserver = {
            help = 'Uždaryti serverį žaidėjams be teisių (tik admin)',
            params = {
                reason = { name = 'reason', help = 'Uždarymo priežastis (nebūtina)' },
            },
        },
        car = {
            help = 'Sukurti transportą (tik admin)',
            params = {
                model = { name = 'model', help = 'Transporto modelio pavadinimas' },
            },
        },
        dv = { help = 'Pašalinti transportą (tik admin)' },
        givemoney = {
            help = 'Duoti pinigų žaidėjui (tik admin)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                moneytype = { name = 'moneytype', help = 'Pinigų tipas (cash, bank, crypto)' },
                amount = { name = 'amount', help = 'Suma' },
            },
        },
        setmoney = {
            help = 'Nustatyti žaidėjo pinigų sumą (tik admin)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                moneytype = { name = 'moneytype', help = 'Pinigų tipas (cash, bank, crypto)' },
                amount = { name = 'amount', help = 'Suma' },
            },
        },
        job = { help = 'Peržiūrėti savo darbą' },
        setjob = {
            help = 'Nustatyti žaidėjo darbą (tik admin)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                job = { name = 'job', help = 'Darbo pavadinimas' },
                grade = { name = 'grade', help = 'Darbo laipsnis' },
            },
        },
        gang = { help = 'Peržiūrėti savo gaują' },
        setgang = {
            help = 'Nustatyti žaidėjo gaują (tik admin)',
            params = {
                id = { name = 'id', help = 'Žaidėjo ID' },
                gang = { name = 'gang', help = 'Gaujos pavadinimas' },
                grade = { name = 'grade', help = 'Gaujos laipsnis' },
            },
        },
        ooc = { help = 'OOC žinutė pokalbiui' },
        me = {
            help = 'Rodyti vietinę veiksmo žinutę',
            params = {
                message = { name = 'message', help = 'Žinutės tekstas' }
            },
        },
    },
}

if GetConvar('qb_locale', 'en') == 'lt' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
