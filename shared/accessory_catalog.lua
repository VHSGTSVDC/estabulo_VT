LRRPAccessoryCatalog = {}

local function add(key, group, hashes)
    LRRPAccessoryCatalog[key] = LRRPAccessoryCatalog[key] or {}
    for i, hash in ipairs(hashes) do
        LRRPAccessoryCatalog[key][#LRRPAccessoryCatalog[key] + 1] = {
            id = (('%s_%s_%02d'):format(key, group:gsub('[^%w]+','_'):lower(), i)),
            group = group,
            label = (#hashes > 1 and (('%s %02d'):format(group, i)) or group),
            hash = hash
        }
    end
end

-- Catálogo baseado nos componentes públicos do VORP Stables.
add('blanket','Siltwater',{'0x127E0412','0x20D4A0BF','0x2A6D33E8','0x0DC87A9F','0xFFB1DE72'})
add('blanket','Roanoke Ridge',{'0x19C5E80C','0x3278996D','0x003D34F3','0x64BE7DF8','0xEC040C89'})
add('blanket','Rio Bravo',{'0x269583CA','0x3973A986','0x4A294AF1','0x97EBE669','0xED0190A3'})
add('blanket','Cholla Springs',{'0x342916F3','0x6B2084E5','0x78FB209A','0x8FAD4DFE','0x9DE0EA65'})
add('blanket','Nekoti Rock',{'0x3BA0D76D','0x4BF1F80F','0x5F0F9E4A','0x71DFC3EA','0xF506CA32'})
add('blanket','Manzanita',{'0x4655E362','0xAD283105','0xC2EF5C93','0xC8A467FD','0xDBEF0E96'})
add('blanket','Cotorra',{'0x508B80B9','0x67CAAF37','0xEBB4B70D'})
add('blanket','Bayou',{'0x533A022A','0x823A602A','0xB0F7BDA4','0xBBF05395','0xFDC3D6D3'})
add('blanket','Owanjila',{'0x53B325B7','0x7D637917','0x90A31F96','0x9AD633FC','0xB19B4519','0xC073E2CA','0xC7688D20'})
add('blanket','Millesani',{'0x5894FB24','0x9E468686','0xAB302059','0xD9E17DBB','0xE32A1050'})
add('blanket','Diablo',{'0x7951D487','0xA3D5298D','0xEDCB3D78'})
add('blanket','Iron Cloud',{'0xC097E12C','0xCDD2FB96','0xD333865B','0xE409A807','0xF6484C84'})

add('saddlebags','Standard',{'0x1D4EDB88','0x20AA8620','0x293E17B3','0x2AEFF6CA','0x5277E9BA','0x577EF434','0x8BE10F93','0x9D593283','0xAE110017','0xB4F40DD9','0xC019F804','0xC05AA4AA','0xD048C482','0xE2ADE94C','0xE4108D59','0xE57042B4','0x0E893DFD','0xEEC77E72','0xF0C30271','0xF8FB69CA'})

add('tail','Dreadlocks',{'0x12DBBBAF','0x3B8A8D0C','0x04951F22','0x49CD2991','0x607956E9','0x6DB6F164','0x7522834F','0x84269E43','0x876B27E0','0x88A2AA53','0x96EDC3D1','0x972AC447','0xA8A4673A','0xBCD412B1','0xCE62B5CE','0xDD9F5447','0xEFA67855'})
add('tail','Trançada',{'0x17EB79D3','0x1A3B721B','0x25B51566','0x33E7B1CB','0x4124CC49','0x4F5268A4','0xA3DA055A','0xA62C9657','0xA7438C29','0xB4AB3354','0xC2FA4FF2','0xC74FCC45','0xD143E02D','0xEBC7218B','0xED0397AC','0xF6B0AB06'})
add('tail','Curta',{'0x1BB5EAA1','0x1E9A18C2','0x2E753874','0x3B27D1DD','0x3D212D77','0x5062FC53','0x508AD44A','0x543203ED','0x5F4871C5','0x695B2E3F','0x75C4C716','0x82DB38EE','0x84ADE4E4','0x0AFB492C','0xC0AF3489','0xDCE41557','0xDDB48566','0xEAEAB164'})
add('tail','Regular',{'0x383E86F3','0x3D1F13D4','0x4B51B039','0x574BC82D','0x066C266F','0x69756C80','0x740701A3','0x7A248ABE','0x084D6B90','0x894C290D','0x9CB1CFD8','0xA0775A83','0xA4F0E056','0xB244FE1E','0xCDFF359A','0xE38F5D96','0xEAA5EEE7','0xED787168'})
add('tail','Longa',{'0x1F7A99EA','0x30603BB5','0x3AE050B5','0x5D7FA043','0x0607E6DD','0x073073A2','0x810A5CE0','0xB4374DB1','0xC304EB4C','0xD7D68A7B','0xD9288D47','0xD9EA1916','0xEABBBAB9','0xF4294320','0xF4A3443C','0xF867D611'})

add('mane','Dreadlocks',{'0x1FDC6D0F','0x241D7FBD','0x3A7C2C86','0x483AC803','0x0512377B','0x6038F7FF','0x6D9412B5','0x83563E39','0x96FE6589','0x09A640A3','0xB2FB934B','0xC929BFA7','0xCDC9C8E7','0x0DCF5321','0xE02377D6','0xFF17AB82','0xFFF3B76A'})
add('mane','Trançada',{'0x25627B98','0x2E378E8A','0x3BFE2A17','0x4FCC51B3','0x054A3CB0','0x5D596CCD','0x6F4510C4','0x7D902D5A','0x92B2579E','0x97105EF6','0xA0F4F423','0xA64BFD6D','0xB13D134B','0xCF434F57','0xD4E65BE5','0xDC62E996','0xE9FE04D0'})
add('mane','Curta',{'0x18199F48','0x0354F6B7','0x3F1FEE4C','0x4F148D45','0x52DC15C8','0x5DE62AE8','0x648A3924','0x7098D141','0x86457C9A','0x960C1B33','0x99F5A3FA','0xA4E1B8DE','0xABA8475F','0xB288D42C','0xBD7B6B05','0xC15371C1','0xF2E555D8'})
add('mane','Regular',{'0x130E341A','0x16923E26','0x1A5A45B6','0x2FCAF0CB','0x419D9470','0x41EA9196','0x5445B9C0','0x5ED14B9F','0x66215D77','0x817B10F6','0xA7A4DD49','0xB5F379E6','0xD894BF28','0xE1435081','0xEA46E28C','0xFF020F3A'})
add('mane','Longa',{'0x0235DBF1','0x446A6F01','0x5F0395A3','0x5FE29755','0x0632F2B7','0x6CB9310E','0x838E5EB8','0x94F58186','0x97D095F4','0xA193A97A','0xAA3FAC1A','0x0AFB7C24','0xB881489D','0xC8646863','0xC9D16B31','0xE0BC27A6','0xFC74DF3B'})

add('saddle','Lumley McClelland',{'0x106961A8','0x150D0DAA','0x17153A45','0x1C14443F','0x01F7C4C5','0x2E4668A3','0x2ECD9E70','0x3D0C3AED','0x3F9F62CE','0x4B372288','0x05D717C9','0x78F07DFA','0xC04FE429','0xD97573C1','0x0DE47F51','0xEB1139AB','0xF3BEA853','0xF94D5623'})
add('saddle','Kneller Mother Hubbard',{'0x14168240','0x2844E292','0x3E949A74','0x5B6390D9','0x5BBC54C3','0x6D403492','0x70BB7EC1','0x7FD859C2','0x87F421F7','0x8D163776','0x8D9D754C','0x9CD94BC1','0xBA6A921E','0xBB335077','0xC1AF1568','0xCE8C2F22','0xD11CBF82','0xF36A78DE'})
add('saddle','Kneller Dakota',{'0x15FB6791','0x3827D232','0x40C53D24','0x47D2CB3F','0x9533FA8E','0xA7AC9F7B','0xB7B33F88','0xB9BE555D','0xC7FC601A','0xDA36048D','0xE039FC0F','0xE36C8274','0xE52BAC3F','0xEC882931','0x0F2F0045','0xF4B14B4A','0xF687A8AA'})
add('saddle','Gerden Vaquero',{'0x189F7005','0x1D0BF8F2','0x01EC65C0','0x219D85E2','0x4C1A5ADB','0x0522CCED','0x5546EB7A','0x5B45F932','0x7092A211','0x7DBB3E1C','0x8E64DDB5','0x8FFCF06B','0x0A39D34E','0xAD4A6355','0xBE703DF7','0xBFD09512','0xC0C04297','0xD2FA64BC','0xE5510BB8','0xE6488B58','0xF1BAA60D','0xF7682D97'})
add('saddle','Gerden Trail Saddle',{'0x1EE21489','0x20359E53','0x24F24446','0x2E3F3A62','0x0306806F','0x335DC49F','0x534A7D59','0x660B29F9','0x6C622F8C','0x70C65BED','0x08E22730','0x093B7057','0xC454830C','0xD6BF27E1','0xD7FC86BF','0xE9B7AA35','0x0F4118E4','0xFCE1D7A4'})
add('saddle','Stenger Roping',{'0x21E8DDFA','0x2E216DBC','0x2F8C7941','0x5A9E4F6C','0x60DE5335','0x6384D886','0x64CEC6DF','0x694DE418','0x76887E89','0x8DABACD7','0x90489DD2','0x9E0C3959','0xB61F0668','0xBC52F5E6','0xC7D58D0B','0xD61B2996','0xDA84CF33','0xFD4E14C5'})
add('saddle','Lumley Ranch Cutter',{'0x6FEABF89','0x7A23C686','0x7C19770A','0x7C2C580C','0x88C363C5','0x8DD09A7C','0x93DA8768','0x9B1C95F8','0x9FF23EBF','0xA1154105','0xA21923E5','0xA8DB3175','0xB357E58A','0xC10B5450','0xD2C8F7CB','0xE5B31D9F','0xF373B920','0xFC6AF7AF'})
add('saddle','Beaver Roping Castor',{'0x2BEA8ED4'})
add('saddle','Cougar McClelland',{'0x353FC03C'})
add('saddle','Rattlesnake Vaquero',{'0x7D795D72'})
add('saddle','Alligator Ranch Cutter',{'0xB5802A5F'})
add('saddle','Panther Trail',{'0xC76C46D9'})
add('saddle','Boar Mother Hubbard',{'0xD225CCA0'})
add('saddle','Bear Dakota',{'0xDE5A2905'})

add('lantern','Lanterna',{'0x635E387C'})
add('mask','Máscara',{'0xFA5B72BB','0xF606EC4A','0xEEF65F11','0xEC10D626','0xE3278C28','0xDDCDB9A0','0xD70C73EA','0xC907FCA9','0xC70D8F40','0xBD887906','0xB567EBF5','0xB395D1C5','0xB0395F88','0xA45049C6','0x9DB125FC','0x9A11B219','0x9946F874','0x90A62272','0x8DCC1CBE','0x8DB38601','0x8C471684','0x872A0C5A','0x7BFA791B','0x7A773AC1','0x702A4AF3','0x6B355791','0x69CD996E','0x68FB97DE','0x68DB4FAD','0x62C5B02A','0x61BEAE08','0x4E22622C','0x4C8C83A4','0x406FC6C7','0x30044BAC','0x226B2F76','0x13AC6E51','0x08A78F53','0xF0ED62FF','0xF17728C7'})


-- v0.5: componentes oficiais adicionais do VORP Stables.
add('stirrups','Estribos',{'0x03B3AB08','0x587DD49F','0x67AF7302','0x75178DD2','0x8246282F','0x8D0BC7DA','0x9EE8E174','0xBDF19F85','0xCB9A3AD6','0xD8AE54FE','0xE73FF221'})
add('bedroll','Bedroll de Lã',{'0x12F0DF9F','0x18BB6B30','0x1B43F045','0x55A0E4FE','0x69B21ADD','0x7B55D476','0x8C9F7709','0x9FD99D7D','0x0AC1F34C','0xD8258E14','0xFFB0391E'})
add('bedroll','Bedroll de Lona',{'0x27543EBB','0x36BEDD90','0x4B7E0712','0x73D157B4','0x841C784A','0xA1FD8B43','0xB4532FEE','0xBC664014','0xD020E789'})
add('bedroll','Bedroll de Lã Acolchoada',{'0x45FEA6D8','0x69B29DC5','0x72FCB059','0x7C8A149A','0x084E5AFA','0x8DD7B735','0x98214B1C','0x9D868568','0xA643680C','0xD258EF10'})

-- Preços da v0.4. Alguns itens alternam para ouro como opções premium.
for category, items in pairs(LRRPAccessoryCatalog) do
    local base = (Config.Accessories and Config.Accessories.categoryPrices and Config.Accessories.categoryPrices[category]) or 50
    for index, item in ipairs(items) do
        item.currency = 0
        item.price = base + math.floor((index - 1) / 5) * math.max(5, math.floor(base * 0.08))
        if Config.Accessories and Config.Accessories.premiumEvery and Config.Accessories.premiumEvery > 0 and index % Config.Accessories.premiumEvery == 0 then
            item.currency = 1
            item.price = Config.Accessories.premiumGoldPrice or 2
        end
    end
end

LRRPAccessoryCategories = {
    { key='saddle', label='Selas', icon='🪶' },
    { key='blanket', label='Mantas', icon='🛏️' },
    { key='saddlebags', label='Alforjes', icon='👜' },
    { key='stirrups', label='Estribos', icon='🦶' },
    { key='bedroll', label='Bedrolls', icon='🛏️' },
    { key='lantern', label='Lanternas', icon='🏮' },
    { key='mask', label='Máscaras', icon='🎭' },
    { key='mane', label='Crinas', icon='🐴' },
    { key='tail', label='Caudas', icon='🐴' }
}

function LRRPAccessoryFind(category, hash)
    hash = tostring(hash or ''):upper()
    for _, item in ipairs(LRRPAccessoryCatalog[category] or {}) do
        if tostring(item.hash):upper() == hash then return item end
    end
    return nil
end
