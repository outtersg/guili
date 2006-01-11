<?php

require_once('xml/chargeur.php');
require_once('xml/compo.php');

# Gère les runtime->library->export
class Machineur extends Compo
{
	protected $r;
	
	function Machineur(&$resultats) { $this->r = &$resultats; }
	function &entrerDans($depuis, $nom, $attributs)
	{
		if($depuis === $this && $nom == 'library')
		{
			$this->r['Bundle-ClassPath'][] = $attributs['name'];
			return $this->r['Bundle-ClassPath'];
		}
		if($depuis === $this->r['Bundle-ClassPath'] && $nom = 'export')
		{
			if($attributs['name'] == '*')
			{
				exec('jar tf '.escapeshellarg($GLOBALS['dossier'].'/'.$this->r['Bundle-ClassPath'][count($this->r['Bundle-ClassPath']) - 1]).' | sed -e \'/\\.class$/!d\' -e \'s=/[^/]*$==\' | sort -u | tr / .', $resultats);
				if(!isset($this->r['Provide-Package'])) $this->r['Provide-Package'] = array();
				$this->r['Provide-Package'] = array_merge($this->r['Provide-Package'], $resultats);
			}
			/* À FAIRE: les autres cas que *. Mais y en a-t-il? */
		}
	}
}

class Capricieur extends Compo
{
	protected $r;
	
	function Capricieur(&$resultats) { $this->r = &$resultats; }
	function &entrerDans($depuis, $nom, $attributs)
	{
		if($nom == 'import') $this->r['Require-Bundle'][] = $attributs['plugin'];
	}
}

class Composanteur extends Compo
{
	protected $r;
	protected $machineur;
	protected $capricieur;
	
	function Composanteur(&$resultats) { $this->r = &$resultats; $this->machineur = new Machineur(&$resultats); $this->capricieur = new Capricieur(&$resultats); }
	function &entrerDans($depuis, $nom, $attributs)
	{
		switch($nom)
		{
			case 'runtime': return $this->machineur;
			case 'requires': return $this->capricieur;
		}
	}
}

class Racineur extends Compo
{
	protected $r;
	protected $composanteur;
	
	function Racineur(&$resultats) { $this->r = &$resultats; $this->composanteur = new Composanteur(&$resultats); }
	function &entrerDans($depuis, $nom, $attributs)
	{
		$this->r['Bundle-Name'] = $attributs['name'];
		$this->r['Bundle-SymbolicName'] = $attributs['id'].'; singleton=true';
		$this->r['Bundle-Version'] = $attributs['version'];
		$this->r['Bundle-Vendor'] = $attributs['provider-name'];
		$this->r['Bundle-Activator'] = $attributs['class'];
		$this->r['Plugin-Class'] = $attributs['class'];
		return $this->composanteur;
	}
}

/*- Programme principal ------------------------------------------------------*/

$ordre = array('Manifest-Version', 'Generated-from', 'Bundle-Name', 'Bundle-SymbolicName', 'Bundle-Version', 'Bundle-ClassPath', 'Bundle-Activator', 'Bundle-Vendor', 'Bundle-Localization', 'Provide-Package', 'Require-Bundle', 'Eclipse-AutoStart', 'Plugin-Class');

$dossier = substr($argv[1], 0, strrpos($argv[1], '/'));

$type = strlen($argv[1]);
$type = ($type >= 0xc && substr($argv[1], $type - 0xc) == 'fragment.xml') ? 4 : 2;

$r = array();
$r['Manifest-Version'] = '1.0';
$t = stat($argv[1]);
$r['Generated-from'] = ($t['mtime'] * 1000).';type='.$type; // En millisecondes pour Java.
$r['Bundle-Activator'] = 'org.eclipse.core.internal.compatibility.PluginActivator'; // Par défaut
$r['Bundle-Localization'] = 'plugin'; // Ce doit être le répertoire depuis lequel on est appelé.
$r['Eclipse-AutoStart'] = 'true';
$r['Plugin-Class'] = 'net.sourceforge.phpeclipse.PHPeclipsePlugin';

/*--- Lecture du XML ---*/

$racineur = new Racineur(&$r);
$chargeur = new Chargeur();
$chargeur->charger($argv[1], null, $racineur);

/*--- Affichage des résultats ---*/

foreach($ordre as $cle)
{
	if(array_key_exists($cle, $r))
	{
		if(is_array($r[$cle]))
		{
			echo $cle.': ';
			if(count($r[$cle]) >= 0)
				echo $r[$cle][0];
			for($i = 1; $i < count($r[$cle]); ++$i)
				echo ",\n ".$r[$cle][$i];
			echo "\n";
		}
		else
			echo $cle.': '.$r[$cle]."\n";
	}
}

?>
