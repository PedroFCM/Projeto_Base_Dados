-- Queries
select a.nome as Nome, e.nome as Equipa from atleta a, equipa e 
where a.nome = "Tomás Azevedo" and a.idEquipa = e.idEquipa;

-- Apresenta o total pago por teste clinico(soma dos exames) por atleta, ordenado pelo total pago
select a.nome as "Nome do Atleta",
    m.data_Agendada as "Data agendada para o Teste Clínico",
    coalesce(sum(e.preco),0) as "Total pago"
from Marcacao m
inner join Atleta a on a.nif_Atleta = m.nif_Atleta
inner join Teste_Clinico t on m.idTeste_Clinico = t.idTeste_Clinico
left join Exame e on e.idTeste_Clinico = t.idTeste_Clinico
group by a.nome, m.data_Agendada
order by sum(e.preco);

select * from exame;

-- Atletas com mais de 180 cm
SELECT 
    a.nome AS Nome, t.altura AS Altura
FROM
    atleta a,
    marcacao m,
    teste_clinico t
WHERE
    m.idTeste_Clinico = t.idTeste_Clinico
        AND m.nif_Atleta = a.nif_Atleta
        AND t.altura > 180;
      
-- Marcacoes do atleta 3
SELECT DISTINCT
    a.nome AS Nome, m.data_Agendada AS DataConsulta
FROM
    atleta a,
    marcacao m,
    teste_clinico t
WHERE
    a.nif_Atleta = m.nif_Atleta
        AND a.nif_Atleta = 3; 

select * from teste_clinico;
select * from marcacao;
select * from atleta;


-- FUNCTIONS ------------------------------------------------------------------
SET GLOBAL log_bin_trust_function_creators = 1;

-- 1) Funcao que calcula a idade de uma pessoa
drop function if exists idade;

delimiter //
create function idade(dat date) returns int
begin 
return (TIMESTAMPDIFF(YEAR, dat, CURDATE()));
end //
delimiter ; 

-- 2) Funcao que devolve o numero de atletas que vivem na localidade X
drop function if exists qtsAtletasLocalidade;

delimiter //
create function qtsAtletasLocalidade(loc varchar(100)) returns int 
begin
return(
SELECT 
    COUNT(*)
FROM
    atleta a,
    codigo_postal c
WHERE
    a.idCodigo_Postal = c.idCodigo_Postal
        AND c.Localidade = loc
);
end//
delimiter ;

select qtsAtletasLocalidade("Lisboa");

-- 3) Funcao que diz o numero de medicos na localidade X
drop function if exists qtsMedicosLocalidade;

delimiter //
create function qtsMedicosLocalidade(loc varchar(100)) returns int
begin
return(
SELECT 
    COUNT(*)
FROM
    medico m,
    codigo_postal c
WHERE
    m.idCodigo_Postal = c.idCodigo_Postal
        AND c.Localidade = loc
);
end//
delimiter ;

select qtsMedicosLocalidade("Famalicao");

-- 4) Funcao que indica o preco dos exames do medico X
drop function if exists fatMedico;

delimiter //
create function fatMedico(medico varchar(100)) returns float
begin
return(
select coalesce(sum(e.preco),0) as Total_Faturado from exame e, medico m
where m.nif_Medico = e.nif_Medico and m.nome = medico
);
end//
delimiter ;

select fatMedico("Pedro Machado");


-- TRIGGERS --------------------------------------------------------------------------------
-- 1) Trigger que faz desconto para 10 euros caso o preco do exame seja superior a 25€
--    acrescenta à tabela consultasDesconto também

drop table if exists consultasdesconto;
create table consultasDesconto (descricao varchar(100), idExame int, preco int, dataDesconto datetime);

drop trigger if exists DescontoExame;

delimiter //
create trigger DescontoExame after update on exame
	for each row
	begin
		if(OLD.preco > 25 and new.preco = 10) then
			insert into consultasDesconto values(new.descricao, new.idExame, new.preco, now());
		end if;
	end //
delimiter ;

update exame set preco = 10 where idExame = 1;   -- fazer desconto no exame 1
select * from exame;
select * from consultasdesconto;

-- 2) Trigger que cria uma tabela com os atletas que foram aprovados
--    acrescenta à tabela atletasAprovados também

-- delete from exame;

drop table if exists atletasAprovados;
create table atletasAprovados (nome varchar(100), genero varchar(45), equipa varchar(100), exame varchar(100));

drop trigger if exists AprovaAtleta;

delimiter //
create trigger AprovaAtleta after insert on exame
	for each row
    begin
	if(new.descricao = "Aprovado") then
		insert into atletasAprovados
			select atleta.nome, atleta.genero, equipa.nome, new.nome
			from atleta, equipa, marcacao, teste_clinico
			where atleta.nif_Atleta = marcacao.nif_Atleta 
				and teste_clinico.idTeste_Clinico = marcacao.idTeste_Clinico 
				and teste_clinico.idTeste_Clinico = new.idTeste_Clinico 
				and equipa.idEquipa = atleta.idEquipa 
				and new.descricao = "Aprovado";
		end if;
    end //
    
delimiter ;

select * from exame;
select * from atletasaprovados;


-- PROCEDURES -------------------------------------------------------------------
-- 1) Procedure que dado um médico, indica os atletas que tiveram consultas com ele

drop procedure if exists AtletasComMedico;

delimiter //
create procedure AtletasComMedico(in medicoX varchar(100))
begin
SELECT 
    atleta.nome AS NomeAtleta,
    marcacao.data_Agendada AS DataMarcacao
FROM
    medico
        INNER JOIN
    marcacao ON marcacao.nif_Medico = medico.nif_Medico
        AND medico.nome = medicoX
        INNER JOIN
    atleta ON atleta.nif_Atleta = marcacao.nif_Atleta;
end//

delimiter ;

call AtletasComMedico("Pinto Varandas");

-- 2) Procedure com cursor que agenda uma marcação em atletas de uma Equipa
drop procedure if exists marcaEquipa;

delimiter //
create procedure marcaEquipa(in nome_equipa varchar(100), nMedico varchar(100), dataM varchar(100))
begin 
	declare finished integer default 0;
    declare nifA int;
    declare atletaCursor cursor for
		select a.nif_Atleta from atleta a, equipa e
        where a.idEquipa = e.idEquipa and e.nome = nome_equipa;
	
    declare continue handler for not found set finished = 1;
    
    open atletaCursor;
    getAtleta: loop
		fetch atletaCursor into nifA;
        if finished = 1 then leave getAtleta;
		end if;
        insert into teste_clinico values();
        set @lastIdTeste = last_insert_id();
        insert into marcacao (data_Agendada, nif_Atleta, nif_Medico, idTeste_Clinico) values(dataM, nifA, nMedico, @lastIdTeste);
	end loop getAtleta;
    close atletaCursor;
end //
delimiter ;

call marcaEquipa("Papa Léguas",1111111111, "2020-02-23");
call marcaEquipa("Sporting",1111111111, "2020-02-01");
select * from marcacao;
select * from teste_clinico;
select last_insert_id();


-- 3) Procedure que indica se um Atleta se encontra apto pelo resultado da ultima marcacao
drop procedure if exists isApto;

delimiter //
create procedure isApto(in nome_Atleta varchar(100))
begin
	select e.descricao as "Status", t.data as "Data do Teste Clínico"
	from Exame e, Teste_Clinico t, Atleta a, Marcacao m
	where a.nome = nome_Atleta and m.nif_Atleta = a.nif_Atleta 
	and e.idTeste_Clinico = t.idTeste_Clinico and t.idTeste_Clinico = m.idTeste_Clinico
	order by t.data desc, e.descricao desc 
    limit 1;
end //
delimiter ;

call isApto("Tsanko Arnaudov");

-- 4) Procedure que muda a Equipa de um atleta

drop procedure if exists mudarEquipaAtleta;

delimiter //
create procedure mudarEquipaAtleta (in nome_atleta varchar(45),
									in nova_equipa int)
begin

	declare v_error bool default 0;
	declare continue handler for sqlexception set v_error = 1;

	set autocommit = OFF;
	
	start transaction;
    
    update 
		Atleta 
	set idEquipa = nova_equipa 
    where nome = nome_atleta;
    
	if (v_error) then rollback;
    end if;
    
    commit;

end //
delimiter ;

call mudarEquipaAtleta("Nelson Évora", 2);


-- 5) Procedure que adiciona dados ao teste clinico agendado

drop procedure if exists atualizaTeste;

delimiter //
create procedure atualizaTeste (idTeste int, 
					naltura int, npeso int, press int, freq int, imc int, ndata datetime)
begin
	declare v_error bool default 0;
	declare continue handler for sqlexception set v_error = 1;
	set autocommit = OFF;
	start transaction;
    
    update 
		teste_clinico 
	set altura = naltura, peso = npeso, pressao_arterial = press, 
    freq_cardiaca = freq, indice_massa_corporal = imc, data = ndata 
    where idTeste_Clinico = idTeste;
    
	if (v_error) then rollback;
    end if;
    commit;

end //
delimiter ;

call atualizaTeste(4, 178, 78, 10, 80, 20, "2019-12-31T10:00:00");
select * from teste_clinico;

-- VIEW -----------------------------------------------------------------------------

-- 1) View que apresenta uma os atletas que são da modalidade "Corrida de pista"
drop view if exists AtletasCorridaPista;

CREATE VIEW AtletasCorridaPista AS
    SELECT 
        a.nome AS Nome,
        c.descricao_Categorias AS Categoria,
        m.nome AS Modalidade
    FROM
        atleta a,
        categorias_modalidade c,
        modalidade m
    WHERE
        a.nif_Atleta = c.nif_Atleta
            AND c.idModalidade = m.idModalidade
            AND m.nome = 'Corrida de Pista';

select * from AtletasCorridaPista;

-- 2) View que indica os Atletas da Localidade "Lisboa"
drop view if exists AtletasLisboa;

CREATE VIEW AtletasLisboa AS
    SELECT 
        a.nome AS Nome, e.nome AS Equipa, c.codigo AS Codigo_Postal
    FROM
        atleta a,
        codigo_postal c,
        equipa e
    WHERE
        a.idCodigo_Postal = c.idCodigo_Postal
            AND c.Localidade = 'Lisboa'
            AND e.idEquipa = a.idEquipa;

select * from AtletasLisboa;

-- 3) View que conta o numero de atletas e medicos em cada Localidade

drop view if exists NLocalidade;

CREATE VIEW NLocalidade AS
    SELECT 
        c.Localidade AS Localidade,
        QTSMEDICOSLOCALIDADE(c.Localidade) AS Medicos,
        QTSATLETASLOCALIDADE(c.Localidade) AS Atletas
    FROM
        atleta a,
        codigo_postal c,
        medico m
    GROUP BY c.Localidade;
        
select * from NLocalidade;

-- 4) View que apresenta os Medicos com mais Marcacoes
drop view if exists MedicoMaisMarcacoes;

CREATE VIEW MedicoMaisMarcacoes AS
    SELECT 
        m.nome AS Nome, IDADE(m.data_nascimento) AS Idade,
        count(ma.idTeste_Clinico) as NumeroConsultas
    FROM
        medico m,
        marcacao ma
    WHERE
        ma.nif_Medico = m.nif_Medico
    GROUP BY ma.nif_Medico
    ORDER BY ma.nif_Medico ASC
    LIMIT 1;

select * from MedicoMaisMarcacoes;

-- 5) View que indica os Atletas da Equipa "Nike"
drop view if exists AtletasNike;

CREATE VIEW AtletasNike AS
    SELECT 
        Atleta.nome AS Nome,
        Atleta.pais AS País,
        Atleta.genero AS Género
    FROM
        Atleta
            INNER JOIN
        Equipa ON Atleta.idEquipa = Equipa.idEquipa
            AND Equipa.nome = 'Nike'
    ORDER BY Atleta.pais ASC;

select * from AtletasNike;

-- 6)  View que seleciona todos atletas com marcacoes futuras
drop view if exists MarcacaoFutura;

create view MarcacaoFutura
as
SELECT 
    a.nome AS 'Nome do Atleta',
    m.data_Agendada AS 'Teste agendado, mas não realizado'
FROM
    Marcacao m
        INNER JOIN
    Atleta a ON a.nif_Atleta = m.nif_Atleta
        INNER JOIN
    Teste_Clinico t ON m.idTeste_Clinico = t.idTeste_Clinico
        LEFT JOIN
    Exame e ON e.idTeste_Clinico = t.idTeste_Clinico
WHERE
    e.idExame IS NULL;

select * from MarcacaoFutura;
select * from teste_clinico;

select * from marcacao;


