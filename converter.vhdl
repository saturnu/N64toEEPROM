library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;
 
--Convertisseur N64 Maskrom vers NAND
 
entity test is
port(
                        --CLOCK
                        ICLOCK  : in std_logic;
 
                        --NAND
                        E               : out   std_logic;
                        G               : out   std_logic;
                        A               : out   std_logic_vector(31 downto 0);
                       
                        --N64 MASKROM
                        AD              : in    std_logic_vector(15 downto 0);
                        READ    : in    std_logic;
                        ALE_H   : in    std_logic;
                        ALE_L   : in    std_logic
        );
end test;
 
architecture Behavioral of test is
signal N64_ADDRESS : std_logic_vector(31 downto 0);
signal NAND_STATE : integer range 0 to 8:=0;
shared variable NEXT_NAND_STATE : integer range 0 to 8:=0;
begin
 
 
        process(ICLOCK)
        variable last_read : std_logic:='0';
        variable last_read2 : std_logic:='0';
        variable last_write2 : std_logic:='0';
        variable last_ale_l : std_logic:='0';
        variable last_ale_l2 : std_logic:='0';
        variable last_ale_h : std_logic:='0';
        variable QUICK_MODE : std_logic:='0';
        variable E_G_OFFSET: integer range 0 to 8; --Delai entre E et G
        variable E_G_TICKS : integer range 0 to 10; --Durée de E et G
        variable CUR_E_G_TICKS : integer:=0;
        begin
       
                        --Definitions des variables
                        E_G_OFFSET:=2; --2 Ticks de delai en E et G
                        E_G_TICKS:=10; --10 Ticks pour E et G
 
                        if (ICLOCK'Event and ICLOCK='1')then
                                --Machine à état pour la NAND
                                case (NAND_STATE) is
                                        when 0 => --Idle 1
                                                NEXT_NAND_STATE:=1;
                                                CUR_E_G_TICKS:=0;
                                        when 1 => --Idle 2
                                                NEXT_NAND_STATE:=0;
                                                CUR_E_G_TICKS:=0;
                                        when 2=> --Lecture de la NAND
                                                NEXT_NAND_STATE:=3;
                                                CUR_E_G_TICKS:=0;
                                        when 3 => --E à 0
                                                CUR_E_G_TICKS:=CUR_E_G_TICKS+1; --Addition bouffe des macrocels !
                                                if(CUR_E_G_TICKS>=E_G_OFFSET) then
                                                        NEXT_NAND_STATE:=4;
                                                        CUR_E_G_TICKS:=0;
                                                end if;
                                        when 4 => --G à 0
                                                CUR_E_G_TICKS:=CUR_E_G_TICKS+1;
                                                if(CUR_E_G_TICKS>=E_G_TICKS) then
                                                        NEXT_NAND_STATE:=5;
                                                end if;
                                        when 5 => --E à 1
                                                CUR_E_G_TICKS:=CUR_E_G_TICKS+1;
                                                if(CUR_E_G_TICKS>=E_G_TICKS+E_G_OFFSET) then
                                                        NEXT_NAND_STATE:=0;
                                                end if;
                                        when others=> --Inconnu
                                                NEXT_NAND_STATE:=0;
                                end case;
                                NAND_STATE<=NEXT_NAND_STATE;
                       
                                --Process de base
                                --Reset
                                if (ALE_H='1' or ALE_L='1') then
                                        NAND_STATE<=0;
                                        QUICK_MODE:='0';
                                end if;
                       
                                --Quick mode
                                if (last_read2='0' and last_read='1' and ALE_H='0' and ALE_L='0')then   --rising edge
                                        N64_ADDRESS<=N64_ADDRESS+2;
                                        QUICK_MODE:='1';
                                end if;
                               
                                if (last_read='1' and READ='0' and ALE_H='0' and ALE_L='0' and QUICK_MODE='1')then      --falling edge
                                        NAND_STATE<=2;
                                        QUICK_MODE:='0';
                                end if;
                               
                                --Gestion des bits de poids faible
                                if (last_ale_l2='1' and last_ale_l='0' and READ='1')then        --falling edge
                                        N64_ADDRESS(15 downto 0)<=AD;   --transfer complete address after alel goes low
                                        NAND_STATE<=2; --Lecture sur la NAND
                                end if;
                               
                                --Gestion des bits de poids fort
                                if (last_ale_h='1' and ALE_H='0' and READ='1')then      --falling edge
                                        N64_ADDRESS(31 downto 16)<=AD;
                                end if;
                               
                                last_read2:=last_read;
                                last_read:=READ;
                               
                                last_ale_l2:=last_ale_l;
                                last_ale_l:=ALE_L;
                               
                                last_ale_h:=ALE_H;
                        end if;
        end process;
 
        --Gestion de la NAND
        process(NAND_STATE,N64_ADDRESS)
        begin
                        case (NAND_STATE) is
                                when 0=> --Idle 0
                                        E<='1';
                                        G<='1';
                                when 1=> --Idle 1 laisse tel quel !
                                        E<='1';
                                        G<='1';                        
                                when 2=> --On set les adresses sur le bus
                                        A<=N64_ADDRESS;
                                        E<='1';
                                        G<='1';
                                when 3=> --On set E à 0
                                        E<='0';
                                        G<='1';
                                when 4=> --On set G à 0
                                        E<='0';
                                        G<='0';
                                when 5=> -- On set E à 1
                                        E<='1';
                                        G<='0';
                                when others=> --On set G à 1
                                        E<='1';
                                        G<='1';
                        end case;
        end process;
 
end Behavioral;
